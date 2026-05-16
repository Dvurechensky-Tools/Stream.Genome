defmodule StreamGenome.Narrative.MemeEvolution do
  @moduledoc """
  A meme mutation edge used to build family trees and lifecycle timelines.
  """

  use StreamGenome.Narrative.Schema

  alias StreamGenome.Narrative.{Entity, Types}

  schema "meme_evolutions" do
    field :mutation_label, :string
    field :first_seen_at, :utc_datetime_usec
    field :last_seen_at, :utc_datetime_usec
    field :popularity_score, :float, default: 0.0
    field :status, :string, default: "emerging"
    field :metadata, :map, default: %{}

    belongs_to :meme, Entity
    belongs_to :parent_meme, Entity

    timestamps()
  end

  def changeset(evolution, attrs) do
    evolution
    |> cast(attrs, [
      :meme_id,
      :parent_meme_id,
      :mutation_label,
      :first_seen_at,
      :last_seen_at,
      :popularity_score,
      :status,
      :metadata
    ])
    |> validate_required([:meme_id, :mutation_label, :status])
    |> validate_inclusion(:status, Types.meme_statuses())
    |> validate_number(:popularity_score, greater_than_or_equal_to: 0.0)
    |> foreign_key_constraint(:meme_id)
    |> foreign_key_constraint(:parent_meme_id)
  end
end
