defmodule StreamGenome.Intelligence do
  @moduledoc """
  Coordinates durable AI extraction windows.
  """

  import Ecto.Query

  alias StreamGenome.Intelligence.{ExtractionRun, Prompts, ResultProjector}
  alias StreamGenome.Intelligence.Workers.ExtractRunWorker
  alias StreamGenome.Narrative.{ContentItem, ContentSegment}
  alias StreamGenome.Repo

  @default_window_segments 40
  @default_window_chars 8_000

  def create_extraction_run(attrs),
    do: %ExtractionRun{} |> ExtractionRun.changeset(attrs) |> Repo.insert()

  def get_extraction_run!(id), do: Repo.get!(ExtractionRun, id)

  def update_extraction_run(%ExtractionRun{} = run, attrs),
    do: run |> ExtractionRun.changeset(attrs) |> Repo.update()

  def mark_extraction_run_started(%ExtractionRun{} = run) do
    update_extraction_run(run, %{
      status: "awaiting_model",
      started_at: DateTime.utc_now(),
      error_message: nil
    })
  end

  def mark_extraction_run_completed(%ExtractionRun{} = run, result, metadata \\ %{}) do
    update_extraction_run(run, %{
      status: "completed",
      result: result,
      metadata: Map.merge(run.metadata || %{}, stringify_keys(metadata)),
      finished_at: DateTime.utc_now(),
      error_message: nil
    })
  end

  def mark_extraction_run_failed(%ExtractionRun{} = run, error_message) do
    update_extraction_run(run, %{
      status: "failed",
      error_message: error_message,
      finished_at: DateTime.utc_now()
    })
  end

  def source_snapshot(source_id) do
    runs_query = from(r in ExtractionRun, where: r.source_id == ^source_id)
    segments_query = source_transcript_segments(source_id)

    total_segments = Repo.aggregate(segments_query, :count)

    pending_segments =
      segments_query
      |> where(
        [s, _i],
        fragment(
          "coalesce(?->>'intelligence_status', '') IN ('', 'ready', 'awaiting_model')",
          s.metadata
        )
      )
      |> Repo.aggregate(:count)

    ready_segments =
      segments_query
      |> where([s, _i], fragment("?->>'intelligence_status' = 'ready'", s.metadata))
      |> Repo.aggregate(:count)

    batched_segments =
      segments_query
      |> where([s, _i], fragment("?->>'intelligence_status' = 'batched'", s.metadata))
      |> Repo.aggregate(:count)

    %{
      total_segments: total_segments,
      pending_segments: pending_segments,
      ready_segments: ready_segments,
      batched_segments: batched_segments,
      extracted_segments:
        segments_query
        |> where([s, _i], fragment("?->>'intelligence_status' = 'extracted'", s.metadata))
        |> Repo.aggregate(:count),
      runs_total: Repo.aggregate(runs_query, :count),
      runs_queued: runs_query |> where([r], r.status == "queued") |> Repo.aggregate(:count),
      runs_awaiting_model:
        runs_query |> where([r], r.status == "awaiting_model") |> Repo.aggregate(:count),
      runs_completed: runs_query |> where([r], r.status == "completed") |> Repo.aggregate(:count),
      runs_failed: runs_query |> where([r], r.status == "failed") |> Repo.aggregate(:count),
      runs_projected:
        runs_query
        |> where([r], fragment("?->>'projection_status' = 'projected'", r.metadata))
        |> Repo.aggregate(:count),
      runs_pending_projection:
        runs_query
        |> where([r], r.status == "completed")
        |> where(
          [r],
          fragment("coalesce(?->>'projection_status', '') != 'projected'", r.metadata)
        )
        |> Repo.aggregate(:count),
      cost: source_cost_snapshot(runs_query),
      recent_runs:
        runs_query
        |> order_by([r], desc: r.inserted_at)
        |> limit(5)
        |> Repo.all()
    }
  end

  def queue_source_extraction_windows(source_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)
    max_segments = Keyword.get(opts, :max_segments, @default_window_segments)
    max_chars = Keyword.get(opts, :max_chars, @default_window_chars)

    windows =
      source_id
      |> list_pending_source_segments(limit * max_segments)
      |> build_windows(max_segments, max_chars)
      |> Enum.take(limit)

    runs =
      Enum.map(windows, fn segments ->
        run = create_lore_window!(source_id, segments)
        enqueue_extraction_run!(run)
        mark_segments_batched!(segments, run.id)
        run
      end)

    {:ok, %{runs: runs}}
  end

  def project_completed_source_runs(source_id, opts \\ []),
    do: ResultProjector.project_completed_source_runs(source_id, opts)

  def start_source_ai_autobatch(source_id, opts \\ []) do
    window_count = Keyword.get(opts, :window_count, 5)
    batches = Keyword.get(opts, :batches, 20)
    interval_seconds = Keyword.get(opts, :interval_seconds, 45)

    %{
      source_id: source_id,
      window_count: window_count,
      batches_remaining: batches,
      interval_seconds: interval_seconds
    }
    |> StreamGenome.Intelligence.Workers.SourceAIBatchWorker.new()
    |> Oban.insert()
  end

  defp source_transcript_segments(source_id) do
    ContentSegment
    |> join(:inner, [s], i in ContentItem, on: i.id == s.content_item_id)
    |> where([s, i], i.source_id == ^source_id and s.segment_type == "transcript")
  end

  defp list_pending_source_segments(source_id, limit) do
    source_transcript_segments(source_id)
    |> where(
      [s, _i],
      fragment(
        "coalesce(?->>'intelligence_status', '') IN ('', 'ready', 'awaiting_model')",
        s.metadata
      )
    )
    |> order_by([s, _i], asc: s.occurred_at, asc: s.starts_at_ms, asc: s.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  defp build_windows(segments, max_segments, max_chars) do
    {windows, current, _chars} =
      Enum.reduce(segments, {[], [], 0}, fn segment, {windows, current, chars} ->
        next_chars = chars + String.length(segment.body || "")

        if current != [] and (length(current) >= max_segments or next_chars > max_chars) do
          {[Enum.reverse(current) | windows], [segment], String.length(segment.body || "")}
        else
          {windows, [segment | current], next_chars}
        end
      end)

    [Enum.reverse(current) | windows]
    |> Enum.reject(&(&1 == []))
    |> Enum.reverse()
  end

  defp create_lore_window!(source_id, segments) do
    input_text = window_text(segments)
    first = List.first(segments)
    last = List.last(segments)
    language = first.language || "unknown"

    {:ok, run} =
      create_extraction_run(%{
        source_id: source_id,
        content_item_id: first.content_item_id,
        task: "lore_extraction",
        status: "queued",
        language: language,
        segment_ids: Enum.map(segments, & &1.id),
        input_text: input_text,
        prompt: Prompts.lore_extraction_window(input_text, language),
        metadata: %{
          starts_at_ms: first.starts_at_ms,
          ends_at_ms: last.ends_at_ms,
          occurred_at: first.occurred_at,
          segment_count: length(segments)
        }
      })

    run
  end

  defp enqueue_extraction_run!(run) do
    %{run_id: run.id}
    |> ExtractRunWorker.new()
    |> Oban.insert()
  end

  defp mark_segments_batched!(segments, run_id) do
    Enum.each(segments, fn segment ->
      metadata =
        segment.metadata
        |> Map.put("intelligence_status", "batched")
        |> Map.put("intelligence_run_id", run_id)
        |> Map.put("intelligence_batched_at", DateTime.utc_now())

      segment
      |> ContentSegment.changeset(%{metadata: metadata})
      |> Repo.update!()
    end)
  end

  defp window_text(segments) do
    segments
    |> Enum.map(fn segment ->
      start = format_ms(segment.starts_at_ms)
      stop = format_ms(segment.ends_at_ms)
      "[#{start}-#{stop}] #{segment.body}"
    end)
    |> Enum.join("\n")
  end

  defp source_cost_snapshot(runs_query) do
    runs =
      runs_query
      |> where([r], not is_nil(r.metadata))
      |> Repo.all()

    totals =
      Enum.reduce(
        runs,
        %{input_tokens: 0, output_tokens: 0, total_tokens: 0, cost_usd: 0.0},
        fn run, acc ->
          usage = Map.get(run.metadata || %{}, "ai_usage", %{})

          %{
            input_tokens: acc.input_tokens + usage_token(usage, "prompt_tokens"),
            output_tokens: acc.output_tokens + usage_token(usage, "completion_tokens"),
            total_tokens: acc.total_tokens + usage_token(usage, "total_tokens"),
            cost_usd: acc.cost_usd + metadata_float(run.metadata, "ai_cost_usd")
          }
        end
      )

    recent =
      runs
      |> Enum.filter(&(metadata_float(&1.metadata, "ai_cost_usd") > 0.0))
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
      |> Enum.take(8)
      |> Enum.map(fn run ->
        usage = Map.get(run.metadata || %{}, "ai_usage", %{})

        %{
          id: run.id,
          task: run.task,
          language: run.language,
          inserted_at: run.inserted_at,
          input_tokens: usage_token(usage, "prompt_tokens"),
          output_tokens: usage_token(usage, "completion_tokens"),
          total_tokens: usage_token(usage, "total_tokens"),
          cost_usd: metadata_float(run.metadata, "ai_cost_usd")
        }
      end)

    Map.put(totals, :recent, recent)
  end

  defp usage_token(usage, key) when is_map(usage) do
    case Map.get(usage, key) do
      value when is_integer(value) -> value
      value when is_float(value) -> round(value)
      _other -> 0
    end
  end

  defp usage_token(_usage, _key), do: 0

  defp metadata_float(metadata, key) when is_map(metadata) do
    case Map.get(metadata, key) do
      value when is_float(value) -> value
      value when is_integer(value) -> value / 1
      _other -> 0.0
    end
  end

  defp metadata_float(_metadata, _key), do: 0.0

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp format_ms(nil), do: "?:??"

  defp format_ms(ms) do
    seconds = div(ms, 1000)
    minutes = div(seconds, 60)
    rest = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(rest), 2, "0")}"
  end
end
