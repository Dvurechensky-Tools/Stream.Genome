defmodule StreamGenome.ManualIngest do
  @moduledoc """
  Converts pasted stream/chat text into the same lore ledger used by real ingestion.
  """

  alias StreamGenome.Narrative
  alias StreamGenome.Narrative.Entity
  alias StreamGenome.Repo

  @sample """
  Streamer: Again with the chair arc? I thought we buried this in 2022.
  Mira: The chair arc never died, it evolved into the sandwich tribunal.
  Chat: CHAIR ARC RETURNS
  Streamer: Fine, the chair is canon as a retired villain.
  """

  def sample_text, do: String.trim(@sample)

  def ingest(text, opts \\ []) when is_binary(text) do
    segments = parse_segments(text)

    if segments == [] do
      {:error, :empty_text}
    else
      Repo.transaction(fn ->
        now = DateTime.utc_now()
        external_id = "manual-#{System.system_time(:millisecond)}"

        {:ok, source} =
          Narrative.create_source(%{
            name: Keyword.get(opts, :source_name, "Manual Paste"),
            source_type: "discord",
            external_id: external_id,
            metadata: %{manual: true}
          })

        {:ok, content_item} =
          Narrative.create_content_item(%{
            source_id: source.id,
            kind: "transcript",
            external_id: external_id,
            title: Keyword.get(opts, :title, "Manual stream fragment"),
            published_at: now,
            language: "en",
            metadata: %{manual: true}
          })

        stored_segments =
          segments
          |> Enum.with_index()
          |> Enum.map(fn {{speaker, body}, index} ->
            {:ok, segment} =
              Narrative.create_segment(%{
                content_item_id: content_item.id,
                segment_type: segment_type(speaker),
                speaker_label: speaker,
                body: body,
                starts_at_ms: index * 10_000,
                ends_at_ms: index * 10_000 + 8_000,
                occurred_at: DateTime.add(now, index * 10, :second),
                metadata: %{manual: true}
              })

            segment
          end)

        speaker_entities = create_speaker_entities!(segments, now)
        phrase_entities = create_phrase_entities!(stored_segments, now)
        event = create_ingest_event!(now, length(stored_segments), length(phrase_entities))

        create_speaker_observations!(speaker_entities, stored_segments)
        create_phrase_observations!(phrase_entities, stored_segments)
        create_edges!(speaker_entities, phrase_entities, event, now)

        %{
          content_item: content_item,
          segments: stored_segments,
          speakers: Map.values(speaker_entities),
          phrases: phrase_entities,
          event: event
        }
      end)
    end
  end

  defp parse_segments(text) do
    text
    |> String.split(~r/\R/u, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&parse_line/1)
  end

  defp parse_line(line) do
    case String.split(line, ":", parts: 2) do
      [speaker, body] -> {String.trim(speaker), String.trim(body)}
      [body] -> {"Unknown", String.trim(body)}
    end
  end

  defp segment_type(speaker) do
    if String.downcase(speaker) in ["chat", "чат"], do: "chat", else: "transcript"
  end

  defp create_speaker_entities!(segments, now) do
    segments
    |> Enum.map(fn {speaker, _body} -> speaker end)
    |> Enum.uniq()
    |> Map.new(fn speaker ->
      entity_type =
        if String.downcase(speaker) in ["chat", "чат"], do: "community", else: "person"

      entity =
        get_or_create_entity!(%{
          entity_type: entity_type,
          canonical_name: speaker,
          summary: "Detected speaker from manual stream fragment.",
          first_seen_at: now,
          last_seen_at: now,
          confidence: 0.7,
          metadata: %{manual: true}
        })

      {speaker, entity}
    end)
  end

  defp create_phrase_entities!(segments, now) do
    segments
    |> Enum.flat_map(&candidate_phrases/1)
    |> Enum.frequencies()
    |> Enum.filter(fn {phrase, count} -> count > 1 or phrase == String.upcase(phrase) end)
    |> Enum.take(6)
    |> Enum.map(fn {phrase, count} ->
      entity =
        get_or_create_entity!(%{
          entity_type: if(count > 1, do: "meme", else: "phrase"),
          canonical_name: titleize_phrase(phrase),
          summary: "Detected repeated or emphasized phrase from manual text.",
          first_seen_at: now,
          last_seen_at: now,
          confidence: min(0.95, 0.55 + count * 0.15),
          metadata: %{manual: true, occurrences: count}
        })

      entity
    end)
  end

  defp candidate_phrases(segment) do
    words =
      segment.body
      |> String.replace(~r/[^\p{L}\p{N}\s]/u, " ")
      |> String.split(~r/\s+/u, trim: true)

    bigrams =
      words
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(&Enum.join(&1, " "))

    emphasized =
      words
      |> Enum.filter(fn word -> String.length(word) > 3 and word == String.upcase(word) end)

    (bigrams ++ emphasized)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(String.length(&1) < 5))
  end

  defp titleize_phrase(phrase) do
    phrase
    |> String.downcase()
    |> String.split(" ", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp create_ingest_event!(now, segment_count, phrase_count) do
    {:ok, event} =
      Narrative.create_event(%{
        event_type: "origin",
        title: "Manual Fragment Ingested",
        summary: "Saved #{segment_count} lines and detected #{phrase_count} phrase candidates.",
        started_at: now,
        ended_at: now,
        intensity: min(1.0, 0.2 + segment_count * 0.05 + phrase_count * 0.08),
        metadata: %{manual: true}
      })

    event
  end

  defp get_or_create_entity!(attrs) do
    slug = slugify(attrs.canonical_name)

    Repo.get_by(Entity, slug: slug) ||
      case Narrative.create_entity(Map.put(attrs, :slug, slug)) do
        {:ok, entity} ->
          entity

        {:error, changeset} ->
          raise Ecto.InvalidChangesetError, action: :insert, changeset: changeset
      end
  end

  defp create_speaker_observations!(speaker_entities, segments) do
    Enum.each(segments, fn segment ->
      entity = Map.fetch!(speaker_entities, segment.speaker_label)

      Narrative.create_observation(%{
        entity_id: entity.id,
        content_segment_id: segment.id,
        surface_text: segment.speaker_label,
        observation_type: "mention",
        confidence: 0.8,
        metadata: %{manual: true}
      })
    end)
  end

  defp create_phrase_observations!(phrase_entities, segments) do
    Enum.each(phrase_entities, fn entity ->
      needle = String.downcase(entity.canonical_name)

      segments
      |> Enum.filter(fn segment -> String.contains?(String.downcase(segment.body), needle) end)
      |> Enum.each(fn segment ->
        Narrative.create_observation(%{
          entity_id: entity.id,
          content_segment_id: segment.id,
          surface_text: entity.canonical_name,
          observation_type: "mention",
          confidence: entity.confidence,
          metadata: %{manual: true}
        })
      end)
    end)
  end

  defp create_edges!(speaker_entities, phrase_entities, event, now) do
    first_speaker = speaker_entities |> Map.values() |> List.first()

    if first_speaker do
      Enum.each(phrase_entities, fn phrase ->
        Narrative.create_edge(%{
          from_entity_id: first_speaker.id,
          to_entity_id: phrase.id,
          edge_type: "associated_with",
          event_id: event.id,
          weight: phrase.confidence,
          first_seen_at: now,
          last_seen_at: now,
          evidence: %{manual: true}
        })
      end)
    end
  end

  defp slugify(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end
end
