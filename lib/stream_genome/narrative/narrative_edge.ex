defmodule StreamGenome.Narrative.NarrativeEdge do
  @moduledoc """
  A relationship between graph nodes, optionally grounded in a narrative event.
  """

  use StreamGenome.Narrative.Schema

  alias StreamGenome.Narrative.{Entity, NarrativeEvent, Types}

  schema "narrative_edges" do
    field :edge_type, :string
    field :weight, :float, default: 1.0
    field :first_seen_at, :utc_datetime_usec
    field :last_seen_at, :utc_datetime_usec
    field :evidence, :map, default: %{}

    belongs_to :from_entity, Entity
    belongs_to :to_entity, Entity
    belongs_to :event, NarrativeEvent

    timestamps()
  end

  def changeset(edge, attrs) do
    edge
    |> cast(attrs, [
      :edge_type,
      :from_entity_id,
      :to_entity_id,
      :event_id,
      :weight,
      :first_seen_at,
      :last_seen_at,
      :evidence
    ])
    |> validate_required([:edge_type, :from_entity_id, :to_entity_id])
    |> validate_inclusion(:edge_type, Types.edge_types())
    |> validate_number(:weight, greater_than_or_equal_to: 0.0)
    |> foreign_key_constraint(:from_entity_id)
    |> foreign_key_constraint(:to_entity_id)
    |> foreign_key_constraint(:event_id)
  end
end
