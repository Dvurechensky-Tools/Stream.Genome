defmodule StreamGenome.Graph do
  @moduledoc """
  Boundary for synchronizing the relational lore ledger into a graph database.
  """

  def upsert_entity(entity) do
    adapter().upsert_entity(%{
      id: entity.id,
      type: entity.entity_type,
      name: entity.canonical_name,
      slug: entity.slug,
      first_seen_at: entity.first_seen_at,
      last_seen_at: entity.last_seen_at
    })
  end

  def upsert_edge(edge) do
    adapter().upsert_edge(%{
      id: edge.id,
      type: edge.edge_type,
      from_entity_id: edge.from_entity_id,
      to_entity_id: edge.to_entity_id,
      event_id: edge.event_id,
      weight: edge.weight
    })
  end

  defp adapter do
    Application.get_env(:stream_genome, :graph_adapter, StreamGenome.Graph.LoggingAdapter)
  end
end
