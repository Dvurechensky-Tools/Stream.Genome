defmodule StreamGenome.Narrative.EntityObservation do
  @moduledoc """
  Evidence that an entity appeared in a specific content segment.
  """

  use StreamGenome.Narrative.Schema

  alias StreamGenome.Narrative.{ContentSegment, Entity, Types}

  schema "entity_observations" do
    field :surface_text, :string
    field :observation_type, :string
    field :sentiment, :float
    field :emotion_score, :float
    field :confidence, :float, default: 0.0
    field :metadata, :map, default: %{}

    belongs_to :entity, Entity
    belongs_to :content_segment, ContentSegment

    timestamps()
  end

  def changeset(observation, attrs) do
    observation
    |> cast(attrs, [
      :entity_id,
      :content_segment_id,
      :surface_text,
      :observation_type,
      :sentiment,
      :emotion_score,
      :confidence,
      :metadata
    ])
    |> validate_required([:entity_id, :content_segment_id, :surface_text, :observation_type])
    |> validate_inclusion(:observation_type, Types.observation_types())
    |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> foreign_key_constraint(:entity_id)
    |> foreign_key_constraint(:content_segment_id)
  end
end
