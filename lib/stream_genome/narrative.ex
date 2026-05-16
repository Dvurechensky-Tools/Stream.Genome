defmodule StreamGenome.Narrative do
  @moduledoc """
  Public API for the persistent creator-universe model.
  """

  import Ecto.Query

  alias StreamGenome.Repo

  alias StreamGenome.Narrative.{
    ContentItem,
    ContentSegment,
    CreatorSource,
    Entity,
    EntityAlias,
    EntityLocalization,
    EventLocalization,
    EntityObservation,
    MemeEvolution,
    NarrativeEdge,
    NarrativeEvent,
    SourceScanRun
  }

  def create_source(attrs),
    do: %CreatorSource{} |> CreatorSource.changeset(attrs) |> Repo.insert()

  def update_source(%CreatorSource{} = source, attrs),
    do: source |> CreatorSource.changeset(attrs) |> Repo.update()

  def get_source!(id), do: Repo.get!(CreatorSource, id)

  def get_content_item_by_source_external(source_id, external_id) do
    Repo.get_by(ContentItem, source_id: source_id, external_id: external_id)
  end

  def get_content_item!(id), do: Repo.get!(ContentItem, id)

  def update_content_item(%ContentItem{} = item, attrs),
    do: item |> ContentItem.changeset(attrs) |> Repo.update()

  def get_source_with_scan_runs!(id) do
    CreatorSource
    |> Repo.get!(id)
    |> Repo.preload(
      scan_runs: from(r in SourceScanRun, order_by: [desc: r.inserted_at]),
      content_items:
        from(i in ContentItem,
          order_by: [desc: i.published_at, desc: i.inserted_at],
          limit: 25
        )
    )
  end

  def source_transcript_snapshot(source_id) do
    videos_query =
      ContentItem
      |> where([i], i.source_id == ^source_id)
      |> where([i], i.kind == "video")

    total = Repo.aggregate(videos_query, :count)

    queued =
      videos_query
      |> where([i], fragment("?->>'transcript_status' = 'queued'", i.metadata))
      |> Repo.aggregate(:count)

    completed =
      videos_query
      |> where([i], fragment("?->>'transcript_status' = 'completed'", i.metadata))
      |> Repo.aggregate(:count)

    failed =
      videos_query
      |> where([i], fragment("?->>'transcript_status' = 'failed'", i.metadata))
      |> Repo.aggregate(:count)

    running =
      videos_query
      |> where([i], fragment("?->>'transcript_status' = 'running'", i.metadata))
      |> Repo.aggregate(:count)

    %{
      total: total,
      pending: max(total - queued - running - completed - failed, 0),
      queued: queued,
      running: running,
      completed: completed,
      failed: failed,
      segments: source_segment_count(source_id),
      languages: source_segment_language_counts(source_id),
      recent_failed: list_recent_failed_transcripts(source_id)
    }
  end

  def list_recent_failed_transcripts(source_id, limit \\ 8) do
    ContentItem
    |> where([i], i.source_id == ^source_id)
    |> where([i], i.kind == "video")
    |> where([i], fragment("?->>'transcript_status' = 'failed'", i.metadata))
    |> order_by([i], desc: i.updated_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def list_sources do
    CreatorSource
    |> order_by([s], desc: s.inserted_at, asc: s.name)
    |> Repo.all()
  end

  def create_content_item(attrs),
    do: %ContentItem{} |> ContentItem.changeset(attrs) |> Repo.insert()

  def create_segment(attrs),
    do: %ContentSegment{} |> ContentSegment.changeset(attrs) |> Repo.insert()

  def update_segment(%ContentSegment{} = segment, attrs),
    do: segment |> ContentSegment.changeset(attrs) |> Repo.update()

  def content_item_segment_count(content_item_id) do
    ContentSegment
    |> where([s], s.content_item_id == ^content_item_id)
    |> Repo.aggregate(:count)
  end

  defp source_segment_count(source_id) do
    ContentSegment
    |> join(:inner, [s], i in ContentItem, on: i.id == s.content_item_id)
    |> where([_s, i], i.source_id == ^source_id)
    |> Repo.aggregate(:count)
  end

  defp source_segment_language_counts(source_id) do
    ContentSegment
    |> join(:inner, [s], i in ContentItem, on: i.id == s.content_item_id)
    |> where([_s, i], i.source_id == ^source_id)
    |> group_by(
      [s, _i],
      fragment("coalesce(?, ?->>'language', 'unknown')", s.language, s.metadata)
    )
    |> select([s, _i], %{
      language: fragment("coalesce(?, ?->>'language', 'unknown')", s.language, s.metadata),
      count: count(s.id)
    })
    |> order_by([s, _i], desc: count(s.id))
    |> Repo.all()
  end

  def list_source_videos_for_transcripts(source_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    ContentItem
    |> where([i], i.source_id == ^source_id)
    |> where([i], i.kind == "video")
    |> where(
      [i],
      fragment(
        "coalesce(?->>'transcript_status', '') NOT IN ('completed', 'queued', 'running', 'failed')",
        i.metadata
      )
    )
    |> order_by([i], asc: i.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def queue_source_transcripts(source_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    videos = list_source_videos_for_transcripts(source_id, limit: limit)

    jobs =
      Enum.map(videos, fn item ->
        metadata = Map.put(item.metadata || %{}, "transcript_status", "queued")
        {:ok, _item} = update_content_item(item, %{metadata: metadata})

        %{content_item_id: item.id}
        |> StreamGenome.Crawler.Workers.VideoTranscriptWorker.new()
        |> Oban.insert()
      end)

    {:ok, %{videos: videos, jobs: jobs}}
  end

  def start_source_transcript_autobatch(source_id, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 5)
    batches = Keyword.get(opts, :batches, 20)
    interval_seconds = Keyword.get(opts, :interval_seconds, 60)

    %{
      source_id: source_id,
      batch_size: batch_size,
      batches_remaining: batches,
      interval_seconds: interval_seconds
    }
    |> StreamGenome.Crawler.Workers.SourceTranscriptBatchWorker.new()
    |> Oban.insert()
  end

  def retry_failed_source_transcripts(source_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    videos =
      ContentItem
      |> where([i], i.source_id == ^source_id)
      |> where([i], i.kind == "video")
      |> where([i], fragment("?->>'transcript_status' = 'failed'", i.metadata))
      |> order_by([i], asc: i.updated_at)
      |> limit(^limit)
      |> Repo.all()

    jobs =
      Enum.map(videos, fn item ->
        metadata =
          item.metadata
          |> Map.put("transcript_status", "queued")
          |> Map.delete("transcript_error")

        {:ok, _item} = update_content_item(item, %{metadata: metadata})

        %{content_item_id: item.id}
        |> StreamGenome.Crawler.Workers.VideoTranscriptWorker.new()
        |> Oban.insert()
      end)

    {:ok, %{videos: videos, jobs: jobs}}
  end

  def create_entity(attrs), do: %Entity{} |> Entity.changeset(attrs) |> Repo.insert()
  def create_alias(attrs), do: %EntityAlias{} |> EntityAlias.changeset(attrs) |> Repo.insert()

  def create_entity_localization(attrs),
    do: %EntityLocalization{} |> EntityLocalization.changeset(attrs) |> Repo.insert()

  def create_event_localization(attrs),
    do: %EventLocalization{} |> EventLocalization.changeset(attrs) |> Repo.insert()

  def create_observation(attrs),
    do: %EntityObservation{} |> EntityObservation.changeset(attrs) |> Repo.insert()

  def create_event(attrs),
    do: %NarrativeEvent{} |> NarrativeEvent.changeset(attrs) |> Repo.insert()

  def create_edge(attrs), do: %NarrativeEdge{} |> NarrativeEdge.changeset(attrs) |> Repo.insert()

  def create_meme_evolution(attrs),
    do: %MemeEvolution{} |> MemeEvolution.changeset(attrs) |> Repo.insert()

  def create_source_scan_run(attrs),
    do: %SourceScanRun{} |> SourceScanRun.changeset(attrs) |> Repo.insert()

  def update_source_scan_run(%SourceScanRun{} = scan_run, attrs),
    do: scan_run |> SourceScanRun.changeset(attrs) |> Repo.update()

  def start_source_scan(source_id, attrs \\ []) do
    with %CreatorSource{} = source <- Repo.get(CreatorSource, source_id),
         {:ok, scan_run} <-
           create_source_scan_run(%{
             source_id: source.id,
             status: "queued",
             requested_by: Keyword.get(attrs, :requested_by, "admin"),
             metadata: %{
               source_type: source.source_type,
               source_url: source.url,
               adapter: "placeholder"
             }
           }) do
      %{scan_run_id: scan_run.id}
      |> StreamGenome.Crawler.Workers.SourceScanWorker.new()
      |> Oban.insert()
      |> case do
        {:ok, _job} -> {:ok, scan_run}
        {:error, reason} -> {:error, reason}
      end
    else
      nil -> {:error, :source_not_found}
      error -> error
    end
  end

  def list_active_entities_between(start_at, end_at, opts \\ []) do
    entity_type = Keyword.get(opts, :entity_type)

    Entity
    |> where([e], is_nil(e.first_seen_at) or e.first_seen_at <= ^end_at)
    |> where([e], is_nil(e.last_seen_at) or e.last_seen_at >= ^start_at)
    |> maybe_filter_entity_type(entity_type)
    |> order_by([e], asc: e.entity_type, asc: e.canonical_name)
    |> Repo.all()
  end

  def timeline_events_between(start_at, end_at) do
    NarrativeEvent
    |> where([e], is_nil(e.started_at) or e.started_at <= ^end_at)
    |> where([e], is_nil(e.ended_at) or e.ended_at >= ^start_at)
    |> order_by([e], asc: e.started_at, asc: e.inserted_at)
    |> Repo.all()
  end

  def search_segments(query, opts \\ []) when is_binary(query) do
    limit = Keyword.get(opts, :limit, 25)

    ContentSegment
    |> where([s], ilike(s.body, ^"%#{query}%"))
    |> order_by([s], desc: s.occurred_at, desc: s.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def public_search(query, opts \\ []) when is_binary(query) do
    limit = Keyword.get(opts, :limit, 8)
    query = String.trim(query)

    if query == "" do
      %{query: "", entities: [], events: [], segments: []}
    else
      pattern = "%#{query}%"

      %{
        query: query,
        entities:
          Entity
          |> where([e], ilike(e.canonical_name, ^pattern) or ilike(e.summary, ^pattern))
          |> order_by([e], desc: e.confidence, desc: e.last_seen_at)
          |> limit(^limit)
          |> Repo.all(),
        events:
          public_events_query()
          |> where([e], ilike(e.title, ^pattern) or ilike(e.summary, ^pattern))
          |> order_by([e], desc: e.started_at, desc: e.intensity)
          |> limit(^limit)
          |> Repo.all(),
        segments:
          ContentSegment
          |> where([s], ilike(s.body, ^pattern))
          |> order_by([s], desc: s.occurred_at, desc: s.inserted_at)
          |> limit(^limit)
          |> Repo.all()
      }
    end
  end

  def meme_tree(meme_id) do
    MemeEvolution
    |> where([m], m.meme_id == ^meme_id or m.parent_meme_id == ^meme_id)
    |> preload([:meme, :parent_meme])
    |> order_by([m], asc: m.first_seen_at, asc: m.inserted_at)
    |> Repo.all()
  end

  def graph_snapshot(opts \\ []) do
    limit = Keyword.get(opts, :limit, 250)

    %{
      entities:
        Entity
        |> order_by([e], desc: e.last_seen_at, asc: e.canonical_name)
        |> limit(^limit)
        |> Repo.all(),
      edges:
        NarrativeEdge
        |> order_by([e], desc: e.weight, desc: e.last_seen_at)
        |> limit(^limit)
        |> Repo.all()
    }
  end

  def source_lore_snapshot(source_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 8)

    source_entities_query =
      Entity
      |> where([e], fragment("?->>'source_id' = ?", e.metadata, ^source_id))

    source_events_query =
      public_events_query()
      |> where([e], fragment("?->>'source_id' = ?", e.metadata, ^source_id))

    source_observations_query =
      EntityObservation
      |> join(:inner, [o], s in assoc(o, :content_segment))
      |> join(:inner, [_o, s], i in assoc(s, :content_item))
      |> where([_o, _s, i], i.source_id == ^source_id)

    %{
      counts: %{
        entities: Repo.aggregate(source_entities_query, :count),
        memes:
          source_entities_query
          |> where([e], e.entity_type == "meme")
          |> Repo.aggregate(:count),
        phrases:
          source_entities_query
          |> where([e], e.entity_type == "phrase")
          |> Repo.aggregate(:count),
        events: Repo.aggregate(source_events_query, :count),
        observations: Repo.aggregate(source_observations_query, :count)
      },
      entities:
        source_entities_query
        |> order_by([e], desc: e.last_seen_at, desc: e.confidence, asc: e.canonical_name)
        |> limit(^limit)
        |> Repo.all(),
      memes:
        source_entities_query
        |> where([e], e.entity_type == "meme")
        |> order_by([e], desc: e.last_seen_at, desc: e.confidence, asc: e.canonical_name)
        |> limit(^limit)
        |> Repo.all(),
      events:
        source_events_query
        |> order_by([e], desc: e.started_at, desc: e.inserted_at)
        |> limit(^limit)
        |> Repo.all(),
      observations:
        source_observations_query
        |> preload([o, s, _i], [:entity, content_segment: s])
        |> order_by([o], desc: o.inserted_at)
        |> limit(^limit)
        |> Repo.all()
    }
  end

  def dashboard_snapshot(opts \\ []) do
    limit = Keyword.get(opts, :limit, 8)

    %{
      counts: %{
        sources: Repo.aggregate(CreatorSource, :count),
        content_items: Repo.aggregate(ContentItem, :count),
        segments: Repo.aggregate(ContentSegment, :count),
        entities: Repo.aggregate(Entity, :count),
        memes: Entity |> where([e], e.entity_type == "meme") |> Repo.aggregate(:count),
        events: public_events_query() |> Repo.aggregate(:count),
        edges: Repo.aggregate(NarrativeEdge, :count),
        scan_runs: Repo.aggregate(SourceScanRun, :count)
      },
      entities:
        Entity
        |> order_by([e], desc: e.last_seen_at, desc: e.confidence, asc: e.canonical_name)
        |> limit(^limit)
        |> Repo.all(),
      memes:
        Entity
        |> where([e], e.entity_type == "meme")
        |> order_by([e], desc: e.last_seen_at, desc: e.confidence, asc: e.canonical_name)
        |> limit(^limit)
        |> Repo.all(),
      events:
        public_events_query()
        |> order_by([e], desc: e.started_at, desc: e.inserted_at)
        |> limit(^limit)
        |> Repo.all(),
      edges:
        NarrativeEdge
        |> preload([:from_entity, :to_entity, :event])
        |> order_by([e], desc: e.weight, desc: e.last_seen_at)
        |> limit(^limit)
        |> Repo.all(),
      sources:
        CreatorSource
        |> preload(
          scan_runs: ^from(r in SourceScanRun, order_by: [desc: r.inserted_at], limit: 1)
        )
        |> order_by([s], desc: s.inserted_at, asc: s.name)
        |> limit(^limit)
        |> Repo.all(),
      segments:
        ContentSegment
        |> order_by([s], asc: s.occurred_at, asc: s.inserted_at)
        |> limit(^limit)
        |> Repo.all()
    }
  end

  defp public_events_query do
    NarrativeEvent
    |> where([e], e.title != "Unprocessed intelligence segment")
    |> where([e], fragment("coalesce(?->>'status', '') != 'awaiting_model'", e.metadata))
  end

  defp maybe_filter_entity_type(query, nil), do: query

  defp maybe_filter_entity_type(query, entity_type),
    do: where(query, [e], e.entity_type == ^entity_type)
end
