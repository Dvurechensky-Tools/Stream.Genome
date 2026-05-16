defmodule Mix.Tasks.StreamGenome.CleanDemo do
  @moduledoc """
  Removes deterministic demo lore while preserving real creator-source data.
  """

  use Mix.Task

  import Ecto.Query

  alias StreamGenome.Narrative.{
    ContentItem,
    ContentSegment,
    CreatorSource,
    Entity,
    EntityAlias,
    EntityLocalization,
    EntityObservation,
    EventLocalization,
    MemeEvolution,
    NarrativeEdge,
    NarrativeEvent,
    SourceScanRun
  }

  alias StreamGenome.Repo

  @shortdoc "Remove demo Northstar/Chair Arc data from the database"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    demo_source_ids =
      from(s in CreatorSource,
        where:
          fragment("coalesce(?->>'demo', '') = 'true'", s.metadata) or
            s.external_id == "demo-northstar" or
            s.url == "https://example.test/northstar",
        select: s.id
      )

    demo_item_ids =
      from(i in ContentItem,
        where:
          fragment("coalesce(?->>'demo', '') = 'true'", i.metadata) or
            i.source_id in subquery(demo_source_ids),
        select: i.id
      )

    demo_segment_ids =
      from(s in ContentSegment,
        where:
          fragment("coalesce(?->>'demo', '') = 'true'", s.metadata) or
            s.content_item_id in subquery(demo_item_ids),
        select: s.id
      )

    demo_entity_ids =
      from(e in Entity,
        where: fragment("coalesce(?->>'demo', '') = 'true'", e.metadata),
        select: e.id
      )

    demo_event_ids =
      from(e in NarrativeEvent,
        where: fragment("coalesce(?->>'demo', '') = 'true'", e.metadata),
        select: e.id
      )

    counts =
      Repo.transaction(fn ->
        %{}
        |> put_count(:meme_evolutions, delete_meme_evolutions(demo_entity_ids))
        |> put_count(:edges, delete_edges(demo_entity_ids, demo_event_ids))
        |> put_count(:observations, delete_observations(demo_entity_ids, demo_segment_ids))
        |> put_count(
          :aliases,
          delete_all(from(a in EntityAlias, where: a.entity_id in subquery(demo_entity_ids)))
        )
        |> put_count(
          :entity_localizations,
          delete_all(
            from(l in EntityLocalization, where: l.entity_id in subquery(demo_entity_ids))
          )
        )
        |> put_count(
          :event_localizations,
          delete_all(from(l in EventLocalization, where: l.event_id in subquery(demo_event_ids)))
        )
        |> put_count(
          :events,
          delete_all(from(e in NarrativeEvent, where: e.id in subquery(demo_event_ids)))
        )
        |> put_count(
          :segments,
          delete_all(from(s in ContentSegment, where: s.id in subquery(demo_segment_ids)))
        )
        |> put_count(
          :scan_runs,
          delete_all(from(r in SourceScanRun, where: r.source_id in subquery(demo_source_ids)))
        )
        |> put_count(
          :items,
          delete_all(from(i in ContentItem, where: i.id in subquery(demo_item_ids)))
        )
        |> put_count(
          :sources,
          delete_all(from(s in CreatorSource, where: s.id in subquery(demo_source_ids)))
        )
        |> put_count(
          :entities,
          delete_all(from(e in Entity, where: e.id in subquery(demo_entity_ids)))
        )
      end)

    case counts do
      {:ok, deleted} ->
        Mix.shell().info("Demo cleanup complete:")

        Enum.each(deleted, fn {table, count} ->
          Mix.shell().info("  #{table}: #{count}")
        end)

      {:error, reason} ->
        Mix.raise("Demo cleanup failed: #{inspect(reason)}")
    end
  end

  defp delete_meme_evolutions(demo_entity_ids) do
    from(m in MemeEvolution,
      where:
        fragment("coalesce(?->>'demo', '') = 'true'", m.metadata) or
          m.meme_id in subquery(demo_entity_ids) or
          m.parent_meme_id in subquery(demo_entity_ids)
    )
    |> delete_all()
  end

  defp delete_edges(demo_entity_ids, demo_event_ids) do
    from(e in NarrativeEdge,
      where:
        fragment("coalesce(?->>'demo', '') = 'true'", e.evidence) or
          e.from_entity_id in subquery(demo_entity_ids) or
          e.to_entity_id in subquery(demo_entity_ids) or
          e.event_id in subquery(demo_event_ids)
    )
    |> delete_all()
  end

  defp delete_observations(demo_entity_ids, demo_segment_ids) do
    from(o in EntityObservation,
      where:
        fragment("coalesce(?->>'demo', '') = 'true'", o.metadata) or
          o.entity_id in subquery(demo_entity_ids) or
          o.content_segment_id in subquery(demo_segment_ids)
    )
    |> delete_all()
  end

  defp delete_all(queryable) do
    {count, _result} = Repo.delete_all(queryable)
    count
  end

  defp put_count(counts, key, value), do: Map.put(counts, key, value)
end
