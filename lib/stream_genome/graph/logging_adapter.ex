defmodule StreamGenome.Graph.LoggingAdapter do
  @moduledoc """
  Development graph adapter that logs graph writes until Neo4j or Memgraph is configured.
  """

  require Logger

  @behaviour StreamGenome.Graph.Adapter

  @impl true
  def upsert_entity(entity) do
    Logger.info("graph entity upsert #{inspect(entity)}")
    :ok
  end

  @impl true
  def upsert_edge(edge) do
    Logger.info("graph edge upsert #{inspect(edge)}")
    :ok
  end
end
