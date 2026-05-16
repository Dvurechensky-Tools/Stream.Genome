defmodule StreamGenome.Intelligence.ResultProjector do
  @moduledoc """
  Projects completed model JSON into persistent narrative graph records.
  """

  import Ecto.Query

  alias StreamGenome.Intelligence.ExtractionRun

  alias StreamGenome.Narrative.{
    ContentSegment,
    Entity,
    EntityAlias,
    EntityObservation,
    NarrativeEvent
  }

  alias StreamGenome.Repo

  @entity_sources %{
    "people" => "person",
    "memes" => "meme",
    "phrases" => "phrase",
    "topics" => "topic",
    "conflicts" => "conflict",
    "emotional_markers" => "topic"
  }

  def project_run(%ExtractionRun{status: "completed"} = run) do
    if projected?(run) do
      {:ok, %{entities: 0, events: 0, observations: 0, skipped?: true}}
    else
      Repo.transaction(fn ->
        segments = list_segments(run.segment_ids)
        primary_segment = List.first(segments)

        result = normalize_result(run.result)

        stats =
          result
          |> project_entities(run, primary_segment)
          |> project_events(result, run, primary_segment)

        mark_segments_extracted!(segments, run.id)
        mark_run_projected!(run, stats)

        stats
      end)
    end
  end

  def project_run(%ExtractionRun{}), do: {:error, :run_not_completed}

  def project_completed_source_runs(source_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    runs =
      ExtractionRun
      |> where([r], r.source_id == ^source_id)
      |> where([r], r.status == "completed")
      |> where([r], fragment("coalesce(?->>'projection_status', '') != 'projected'", r.metadata))
      |> order_by([r], asc: r.inserted_at)
      |> limit(^limit)
      |> Repo.all()

    results =
      Enum.map(runs, fn run ->
        case project_run(run) do
          {:ok, stats} -> stats
          {:error, reason} -> %{error: inspect(reason)}
        end
      end)

    {:ok, %{runs: runs, results: results}}
  end

  defp projected?(%ExtractionRun{metadata: metadata}) when is_map(metadata),
    do: metadata["projection_status"] == "projected"

  defp projected?(_run), do: false

  defp normalize_result(result) when is_map(result), do: result
  defp normalize_result(_result), do: %{}

  defp project_entities(result, run, primary_segment) do
    Enum.reduce(@entity_sources, %{entities: 0, events: 0, observations: 0}, fn {key, type},
                                                                                stats ->
      result
      |> Map.get(key, [])
      |> List.wrap()
      |> Enum.reduce(stats, fn item, acc ->
        case entity_name(item, key) do
          nil ->
            acc

          name ->
            confidence = confidence(item)
            entity = upsert_entity!(type, name, run, confidence)
            maybe_create_alias!(entity, name, run, confidence)

            observation_created? =
              maybe_create_observation!(entity, primary_segment, item, key, confidence, run)

            acc
            |> bump(:entities)
            |> maybe_bump(:observations, observation_created?)
        end
      end)
    end)
  end

  defp project_events(stats, result, run, primary_segment) do
    events =
      List.wrap(Map.get(result, "candidate_events", [])) ++
        callback_events(Map.get(result, "callbacks", []))

    Enum.reduce(events, stats, fn item, acc ->
      case event_title(item) do
        nil ->
          acc

        title ->
          create_event!(title, item, run, primary_segment)
          bump(acc, :events)
      end
    end)
  end

  defp callback_events(callbacks) do
    callbacks
    |> List.wrap()
    |> Enum.map(fn callback ->
      callback
      |> ensure_map()
      |> Map.put_new("event_type", "callback")
    end)
  end

  defp upsert_entity!(type, name, run, confidence) do
    slug = slug_for(type, name)
    now = DateTime.utc_now()
    first_seen_at = run_time(run)

    case Repo.get_by(Entity, slug: slug) do
      %Entity{} = entity ->
        {:ok, entity} =
          entity
          |> Entity.changeset(%{
            last_seen_at: max_datetime(entity.last_seen_at, first_seen_at),
            confidence: max(entity.confidence || 0.0, confidence),
            metadata: Map.merge(entity.metadata || %{}, %{"last_projected_run_id" => run.id})
          })
          |> Repo.update()

        entity

      nil ->
        %Entity{}
        |> Entity.changeset(%{
          entity_type: type,
          canonical_name: name,
          slug: slug,
          summary: "#{name} detected by AI lore extraction.",
          first_seen_at: first_seen_at || now,
          last_seen_at: first_seen_at || now,
          confidence: confidence,
          metadata: %{
            "source" => "ai_projector",
            "source_id" => run.source_id,
            "first_projected_run_id" => run.id
          }
        })
        |> Repo.insert!()
    end
  end

  defp maybe_create_alias!(entity, alias_value, run, confidence) do
    attrs = %{
      entity_id: entity.id,
      alias: alias_value,
      first_seen_at: run_time(run),
      last_seen_at: run_time(run),
      confidence: confidence
    }

    %EntityAlias{}
    |> EntityAlias.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing)
  end

  defp maybe_create_observation!(_entity, nil, _item, _key, _confidence, _run), do: false

  defp maybe_create_observation!(entity, segment, item, key, confidence, run) do
    surface_text = entity_name(item, key) || Map.get(ensure_map(item), "marker") || key

    exists? =
      EntityObservation
      |> where([o], o.entity_id == ^entity.id)
      |> where([o], o.content_segment_id == ^segment.id)
      |> where([o], o.surface_text == ^surface_text)
      |> Repo.exists?()

    if exists? do
      false
    else
      %EntityObservation{}
      |> EntityObservation.changeset(%{
        entity_id: entity.id,
        content_segment_id: segment.id,
        surface_text: surface_text,
        observation_type: observation_type(key),
        confidence: confidence,
        metadata: %{
          "source" => "ai_projector",
          "extraction_run_id" => run.id,
          "raw" => ensure_map(item)
        }
      })
      |> Repo.insert!()

      true
    end
  end

  defp create_event!(title, item, run, primary_segment) do
    item = ensure_map(item)

    %NarrativeEvent{}
    |> NarrativeEvent.changeset(%{
      event_type: event_type(item),
      title: title,
      summary: Map.get(item, "description") || Map.get(item, "event") || title,
      started_at: run_time(run),
      intensity: confidence(item),
      metadata: %{
        "source" => "ai_projector",
        "source_id" => run.source_id,
        "content_item_id" => run.content_item_id,
        "content_segment_id" => primary_segment && primary_segment.id,
        "extraction_run_id" => run.id,
        "raw" => item
      }
    })
    |> Repo.insert!()
  end

  defp mark_segments_extracted!(segments, run_id) do
    Enum.each(segments, fn segment ->
      metadata =
        segment.metadata
        |> Map.put("intelligence_status", "extracted")
        |> Map.put("intelligence_projected_at", DateTime.utc_now())
        |> Map.put("intelligence_run_id", run_id)

      segment
      |> ContentSegment.changeset(%{metadata: metadata})
      |> Repo.update!()
    end)
  end

  defp mark_run_projected!(run, stats) do
    metadata =
      run.metadata
      |> Map.put("projection_status", "projected")
      |> Map.put("projected_at", DateTime.utc_now())
      |> Map.put("projection_stats", stats)

    run
    |> ExtractionRun.changeset(%{metadata: metadata})
    |> Repo.update!()
  end

  defp list_segments(ids) do
    ContentSegment
    |> where([s], s.id in ^ids)
    |> order_by([s], asc: s.occurred_at, asc: s.starts_at_ms, asc: s.inserted_at)
    |> Repo.all()
  end

  defp entity_name(item, "emotional_markers"),
    do: item |> ensure_map() |> Map.get("marker") |> clean_name()

  defp entity_name(item, _key), do: item |> ensure_map() |> Map.get("name") |> clean_name()

  defp event_title(item) do
    item = ensure_map(item)
    clean_name(Map.get(item, "event") || Map.get(item, "description") || Map.get(item, "name"))
  end

  defp confidence(item) do
    case Map.get(ensure_map(item), "confidence", 0.65) do
      value when is_float(value) -> clamp(value)
      value when is_integer(value) -> clamp(value / 1)
      value when is_binary(value) -> value |> Float.parse() |> elem_or_default(0.65) |> clamp()
      _other -> 0.65
    end
  end

  defp elem_or_default({value, _rest}, _default), do: value
  defp elem_or_default(:error, default), do: default

  defp event_type(%{"event_type" => "callback"}), do: "callback"
  defp event_type(%{"conflict" => _conflict}), do: "conflict"
  defp event_type(_item), do: "arc_turn"

  defp observation_type("phrases"), do: "quote"
  defp observation_type("emotional_markers"), do: "emotion"
  defp observation_type("callbacks"), do: "callback"
  defp observation_type(_key), do: "mention"

  defp run_time(%ExtractionRun{metadata: %{"occurred_at" => %DateTime{} = value}}), do: value

  defp run_time(%ExtractionRun{metadata: %{"occurred_at" => value}}) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _other -> nil
    end
  end

  defp run_time(%ExtractionRun{} = run), do: run.finished_at || run.started_at || run.inserted_at

  defp max_datetime(nil, value), do: value
  defp max_datetime(value, nil), do: value

  defp max_datetime(%DateTime{} = left, %DateTime{} = right) do
    case DateTime.compare(left, right) do
      :lt -> right
      _other -> left
    end
  end

  defp ensure_map(value) when is_map(value), do: value
  defp ensure_map(value) when is_binary(value), do: %{"name" => value}
  defp ensure_map(_value), do: %{}

  defp clean_name(nil), do: nil

  defp clean_name(value) do
    value
    |> to_string()
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> case do
      "" -> nil
      cleaned -> String.slice(cleaned, 0, 180)
    end
  end

  defp slug_for(type, name), do: "#{type}-#{slugify(name)}"

  defp slugify(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9а-яё]+/u, "-")
    |> String.trim("-")
    |> case do
      "" -> Base.url_encode64(value, padding: false)
      slug -> slug
    end
  end

  defp clamp(value) when value < 0.0, do: 0.0
  defp clamp(value) when value > 1.0, do: 1.0
  defp clamp(value), do: value

  defp bump(stats, key), do: Map.update!(stats, key, &(&1 + 1))
  defp maybe_bump(stats, key, true), do: bump(stats, key)
  defp maybe_bump(stats, _key, false), do: stats
end
