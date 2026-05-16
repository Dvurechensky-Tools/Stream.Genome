defmodule StreamGenome.Demo do
  @moduledoc """
  Small deterministic demo universe used to make the engine visible before
  real platform ingestion is implemented.
  """

  alias StreamGenome.Narrative
  alias StreamGenome.Narrative.{Entity, NarrativeEvent}
  alias StreamGenome.Repo

  @base ~U[2024-04-12 18:00:00Z]

  def load! do
    Repo.transaction(fn ->
      source =
        get_or_create_source!(%{
          name: "Northstar Streams",
          source_type: "youtube",
          external_id: "demo-northstar",
          url: "https://example.test/northstar",
          metadata: %{demo: true}
        })

      content =
        get_or_create_content_item!(%{
          source_id: source.id,
          kind: "stream",
          external_id: "demo-stream-chair-arc",
          title: "Demo Stream: Chair Arc Revival",
          url: "https://example.test/northstar/chair-arc",
          published_at: @base,
          duration_ms: 4_200_000,
          language: "en",
          metadata: %{demo: true}
        })

      segments = create_segments!(content)
      entities = create_entities!()
      create_aliases!(entities)
      create_observations!(entities, segments)
      events = create_events!()
      create_edges!(entities, events)
      create_meme_evolutions!(entities)
    end)

    :ok
  end

  defp create_segments!(content) do
    [
      {"Host", "We are not doing the chair thing again. Chat still remembers 2022.", 0},
      {"Mira", "The chair arc never died, it just waited in the background.", 14_000},
      {"Chat", "CHAIR ARC CHAIR ARC", 18_000},
      {"Host", "This is exactly like the lost sandwich debate, but with furniture.", 32_000},
      {"Chat", "sandwich tribunal returns", 37_000},
      {"Mira", "Every spring this community invents a courtroom for a tiny object.", 51_000},
      {"Host", "Fine. The chair is canon again, but only as a retired villain.", 65_000}
    ]
    |> Enum.map(fn {speaker, body, starts_at_ms} ->
      get_or_create_segment!(%{
        content_item_id: content.id,
        segment_type: if(speaker == "Chat", do: "chat", else: "transcript"),
        speaker_label: speaker,
        body: body,
        starts_at_ms: starts_at_ms,
        ends_at_ms: starts_at_ms + 8_000,
        occurred_at: DateTime.add(@base, div(starts_at_ms, 1000), :second),
        metadata: %{demo: true}
      })
    end)
  end

  defp create_entities! do
    %{
      host:
        get_or_create_entity!(%{
          entity_type: "person",
          canonical_name: "Host",
          summary: "Primary creator in the demo universe.",
          first_seen_at: ~U[2022-03-04 18:00:00Z],
          last_seen_at: @base,
          confidence: 1.0,
          metadata: %{demo: true}
        }),
      mira:
        get_or_create_entity!(%{
          entity_type: "person",
          canonical_name: "Mira",
          summary: "Recurring guest who reframes old jokes into lore.",
          first_seen_at: ~U[2023-09-18 18:00:00Z],
          last_seen_at: @base,
          confidence: 0.94,
          metadata: %{demo: true}
        }),
      chair_arc:
        get_or_create_entity!(%{
          entity_type: "meme",
          canonical_name: "Chair Arc",
          summary: "A long-running joke about a suspicious chair becoming canon.",
          first_seen_at: ~U[2022-03-04 18:00:00Z],
          last_seen_at: @base,
          confidence: 0.96,
          metadata: %{demo: true}
        }),
      sandwich_tribunal:
        get_or_create_entity!(%{
          entity_type: "meme",
          canonical_name: "Sandwich Tribunal",
          summary: "A debate format that turns small objects into courtroom drama.",
          first_seen_at: ~U[2023-04-16 18:00:00Z],
          last_seen_at: @base,
          confidence: 0.91,
          metadata: %{demo: true}
        }),
      spring_courtroom:
        get_or_create_entity!(%{
          entity_type: "arc",
          canonical_name: "Spring Courtroom Pattern",
          summary: "Seasonal narrative structure where chat puts ordinary objects on trial.",
          first_seen_at: ~U[2023-04-16 18:00:00Z],
          last_seen_at: @base,
          confidence: 0.88,
          metadata: %{demo: true}
        }),
      retired_villain:
        get_or_create_entity!(%{
          entity_type: "phrase",
          canonical_name: "Retired Villain",
          summary: "A phrase that mutates old antagonistic memes into nostalgic callbacks.",
          first_seen_at: @base,
          last_seen_at: @base,
          confidence: 0.82,
          metadata: %{demo: true}
        })
    }
  end

  defp create_aliases!(entities) do
    [
      {entities.chair_arc, "chair thing"},
      {entities.chair_arc, "the chair"},
      {entities.sandwich_tribunal, "lost sandwich debate"},
      {entities.sandwich_tribunal, "sandwich court"},
      {entities.spring_courtroom, "object trial season"}
    ]
    |> Enum.each(fn {entity, alias_name} ->
      get_or_create_alias!(%{
        entity_id: entity.id,
        alias: alias_name,
        confidence: 0.9,
        first_seen_at: entity.first_seen_at,
        last_seen_at: entity.last_seen_at
      })
    end)
  end

  defp create_observations!(entities, segments) do
    observations = [
      {entities.chair_arc, Enum.at(segments, 0), "chair thing", "callback", 0.92, 0.64},
      {entities.chair_arc, Enum.at(segments, 1), "chair arc", "mention", 0.95, 0.72},
      {entities.chair_arc, Enum.at(segments, 2), "CHAIR ARC", "reaction", 0.98, 0.89},
      {entities.sandwich_tribunal, Enum.at(segments, 3), "lost sandwich debate", "callback", 0.88,
       0.58},
      {entities.sandwich_tribunal, Enum.at(segments, 4), "sandwich tribunal", "reaction", 0.91,
       0.76},
      {entities.spring_courtroom, Enum.at(segments, 5), "courtroom for a tiny object", "mention",
       0.83, 0.61},
      {entities.retired_villain, Enum.at(segments, 6), "retired villain", "quote", 0.86, 0.7}
    ]

    Enum.each(observations, fn {entity, segment, surface, type, confidence, emotion} ->
      get_or_create_observation!(%{
        entity_id: entity.id,
        content_segment_id: segment.id,
        surface_text: surface,
        observation_type: type,
        confidence: confidence,
        emotion_score: emotion,
        sentiment: 0.42,
        metadata: %{demo: true}
      })
    end)
  end

  defp create_events! do
    %{
      origin:
        get_or_create_event!(%{
          event_type: "origin",
          title: "Chair Arc Origin",
          summary: "The original chair joke becomes a named recurring meme.",
          started_at: ~U[2022-03-04 18:00:00Z],
          ended_at: ~U[2022-03-04 19:00:00Z],
          intensity: 0.62,
          metadata: %{demo: true}
        }),
      sandwich:
        get_or_create_event!(%{
          event_type: "arc_turn",
          title: "Sandwich Tribunal",
          summary: "Chat turns a mundane dispute into a trial format.",
          started_at: ~U[2023-04-16 18:00:00Z],
          ended_at: ~U[2023-04-16 19:00:00Z],
          intensity: 0.71,
          metadata: %{demo: true}
        }),
      revival:
        get_or_create_event!(%{
          event_type: "revival",
          title: "Chair Arc Revival",
          summary: "A 2024 callback revives the old chair meme through the tribunal pattern.",
          started_at: @base,
          ended_at: DateTime.add(@base, 70, :second),
          intensity: 0.86,
          metadata: %{demo: true}
        })
    }
  end

  defp create_edges!(entities, events) do
    [
      {entities.chair_arc, entities.sandwich_tribunal, "references", events.revival, 0.76},
      {entities.sandwich_tribunal, entities.spring_courtroom, "associated_with", events.sandwich,
       0.83},
      {entities.spring_courtroom, entities.chair_arc, "triggered", events.revival, 0.88},
      {entities.chair_arc, entities.retired_villain, "evolved_into", events.revival, 0.67},
      {entities.mira, entities.chair_arc, "repeated_by", events.revival, 0.74},
      {entities.host, entities.chair_arc, "emotionally_linked", events.revival, 0.7}
    ]
    |> Enum.each(fn {from, to, type, event, weight} ->
      get_or_create_edge!(%{
        from_entity_id: from.id,
        to_entity_id: to.id,
        edge_type: type,
        event_id: event.id,
        weight: weight,
        first_seen_at: event.started_at,
        last_seen_at: event.ended_at,
        evidence: %{demo: true}
      })
    end)
  end

  defp create_meme_evolutions!(entities) do
    get_or_create_meme_evolution!(%{
      meme_id: entities.chair_arc.id,
      mutation_label: "Original suspicious chair joke",
      first_seen_at: entities.chair_arc.first_seen_at,
      last_seen_at: entities.chair_arc.last_seen_at,
      popularity_score: 0.78,
      status: "revived",
      metadata: %{demo: true}
    })

    get_or_create_meme_evolution!(%{
      meme_id: entities.retired_villain.id,
      parent_meme_id: entities.chair_arc.id,
      mutation_label: "Old antagonist reframed as nostalgia",
      first_seen_at: @base,
      last_seen_at: @base,
      popularity_score: 0.46,
      status: "emerging",
      metadata: %{demo: true}
    })
  end

  defp get_or_create_source!(attrs) do
    Repo.get_by(StreamGenome.Narrative.CreatorSource,
      source_type: attrs.source_type,
      external_id: attrs.external_id
    ) || insert!(:create_source, attrs)
  end

  defp get_or_create_content_item!(attrs) do
    Repo.get_by(StreamGenome.Narrative.ContentItem,
      kind: attrs.kind,
      external_id: attrs.external_id
    ) || insert!(:create_content_item, attrs)
  end

  defp get_or_create_segment!(attrs) do
    Repo.get_by(StreamGenome.Narrative.ContentSegment,
      content_item_id: attrs.content_item_id,
      starts_at_ms: attrs.starts_at_ms,
      body: attrs.body
    ) || insert!(:create_segment, attrs)
  end

  defp get_or_create_entity!(attrs) do
    slug = attrs[:slug] || slugify(attrs.canonical_name)
    Repo.get_by(Entity, slug: slug) || insert!(:create_entity, Map.put(attrs, :slug, slug))
  end

  defp get_or_create_alias!(attrs) do
    normalized_alias = attrs.alias |> String.downcase() |> String.trim()

    Repo.get_by(StreamGenome.Narrative.EntityAlias,
      entity_id: attrs.entity_id,
      normalized_alias: normalized_alias
    ) || insert!(:create_alias, Map.put(attrs, :normalized_alias, normalized_alias))
  end

  defp get_or_create_observation!(attrs) do
    Repo.get_by(StreamGenome.Narrative.EntityObservation,
      entity_id: attrs.entity_id,
      content_segment_id: attrs.content_segment_id,
      surface_text: attrs.surface_text
    ) || insert!(:create_observation, attrs)
  end

  defp get_or_create_event!(attrs) do
    Repo.get_by(NarrativeEvent, title: attrs.title) || insert!(:create_event, attrs)
  end

  defp get_or_create_edge!(attrs) do
    Repo.get_by(StreamGenome.Narrative.NarrativeEdge,
      from_entity_id: attrs.from_entity_id,
      to_entity_id: attrs.to_entity_id,
      edge_type: attrs.edge_type
    ) || insert!(:create_edge, attrs)
  end

  defp get_or_create_meme_evolution!(attrs) do
    Repo.get_by(StreamGenome.Narrative.MemeEvolution,
      meme_id: attrs.meme_id,
      mutation_label: attrs.mutation_label
    ) || insert!(:create_meme_evolution, attrs)
  end

  defp insert!(function, attrs) do
    case apply(Narrative, function, [attrs]) do
      {:ok, record} ->
        record

      {:error, changeset} ->
        raise Ecto.InvalidChangesetError, action: :insert, changeset: changeset
    end
  end

  defp slugify(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end
end
