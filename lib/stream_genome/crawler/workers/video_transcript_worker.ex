defmodule StreamGenome.Crawler.Workers.VideoTranscriptWorker do
  @moduledoc """
  Fetches subtitles for a video content item and stores them as transcript segments.
  """

  use Oban.Worker, queue: :crawler, max_attempts: 3

  alias StreamGenome.Intelligence.Workers.ExtractSegmentWorker
  alias StreamGenome.Narrative
  alias StreamGenome.YouTube.TranscriptDiscovery

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"content_item_id" => content_item_id}}) do
    item = Narrative.get_content_item!(content_item_id)
    mark_running(item)

    if Narrative.content_item_segment_count(item.id) > 0 do
      mark_completed(item, 0, "already_segmented")
    else
      case TranscriptDiscovery.fetch(item) do
        {:ok, transcript_segments} ->
          created = store_segments(item, transcript_segments)
          mark_completed(item, created, "youtube_subtitles")

        {:error, reason} ->
          mark_failed(item, reason)
      end
    end

    :ok
  end

  defp mark_running(item) do
    metadata =
      item.metadata
      |> Map.put("transcript_status", "running")
      |> Map.put("transcript_started_at", DateTime.utc_now())

    Narrative.update_content_item(item, %{metadata: metadata})
  end

  defp store_segments(item, transcript_segments) do
    transcript_segments
    |> Enum.map(fn segment ->
      {:ok, created} =
        Narrative.create_segment(%{
          content_item_id: item.id,
          segment_type: "transcript",
          body: segment.body,
          language: segment[:language] || "unknown",
          starts_at_ms: segment.starts_at_ms,
          ends_at_ms: segment.ends_at_ms,
          occurred_at: item.published_at,
          metadata: %{
            discovery: "youtube_subtitles",
            source_video_id: item.external_id,
            language: segment[:language] || "unknown"
          }
        })

      %{segment_id: created.id}
      |> ExtractSegmentWorker.new()
      |> Oban.insert()

      created
    end)
    |> length()
  end

  defp mark_completed(item, segment_count, discovery) do
    metadata =
      item.metadata
      |> Map.put("transcript_status", "completed")
      |> Map.put("transcript_segments", segment_count)
      |> Map.put("transcript_discovery", discovery)
      |> Map.put("transcript_finished_at", DateTime.utc_now())

    Narrative.update_content_item(item, %{metadata: metadata})
  end

  defp mark_failed(item, reason) do
    metadata =
      item.metadata
      |> Map.put("transcript_status", "failed")
      |> Map.put(
        "transcript_error",
        inspect(reason, limit: :infinity, printable_limit: :infinity)
      )
      |> Map.put("transcript_finished_at", DateTime.utc_now())

    Narrative.update_content_item(item, %{metadata: metadata})
  end
end
