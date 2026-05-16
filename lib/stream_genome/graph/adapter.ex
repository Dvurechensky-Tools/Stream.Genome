defmodule StreamGenome.Graph.Adapter do
  @moduledoc """
  Behaviour for graph database adapters such as Neo4j or Memgraph.
  """

  @callback upsert_entity(map()) :: :ok | {:error, term()}
  @callback upsert_edge(map()) :: :ok | {:error, term()}
end
