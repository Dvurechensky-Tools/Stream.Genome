defmodule StreamGenome.Narrative.Entity do
  @moduledoc """
  A persistent node in the creator universe graph.
  """

  use StreamGenome.Narrative.Schema

  alias StreamGenome.Narrative.{
    EntityAlias,
    EntityObservation,
    EntityLocalization,
    MemeEvolution,
    NarrativeEdge,
    Types
  }

  schema "narrative_entities" do
    field :entity_type, :string
    field :canonical_name, :string
    field :slug, :string
    field :summary, :string
    field :first_seen_at, :utc_datetime_usec
    field :last_seen_at, :utc_datetime_usec
    field :confidence, :float, default: 0.0
    field :metadata, :map, default: %{}

    has_many :aliases, EntityAlias
    has_many :localizations, EntityLocalization
    has_many :observations, EntityObservation
    has_many :outgoing_edges, NarrativeEdge, foreign_key: :from_entity_id
    has_many :incoming_edges, NarrativeEdge, foreign_key: :to_entity_id
    has_many :meme_evolutions, MemeEvolution, foreign_key: :meme_id

    timestamps()
  end

  def changeset(entity, attrs) do
    entity
    |> cast(attrs, [
      :entity_type,
      :canonical_name,
      :slug,
      :summary,
      :first_seen_at,
      :last_seen_at,
      :confidence,
      :metadata
    ])
    |> put_slug()
    |> validate_required([:entity_type, :canonical_name, :slug])
    |> validate_inclusion(:entity_type, Types.entity_types())
    |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> unique_constraint(:slug)
  end

  defp put_slug(changeset) do
    case {get_field(changeset, :slug), get_field(changeset, :canonical_name)} do
      {nil, name} when is_binary(name) ->
        put_change(changeset, :slug, slugify(name))

      {"", name} when is_binary(name) ->
        put_change(changeset, :slug, slugify(name))

      _ ->
        changeset
    end
  end

  defp slugify(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end
end
