defmodule StreamGenome.Narrative.EntityAlias do
  @moduledoc """
  Nicknames, alternate spellings, and community-specific names for an entity.
  """

  use StreamGenome.Narrative.Schema

  alias StreamGenome.Narrative.Entity

  schema "entity_aliases" do
    field :alias, :string
    field :normalized_alias, :string
    field :first_seen_at, :utc_datetime_usec
    field :last_seen_at, :utc_datetime_usec
    field :confidence, :float, default: 0.0

    belongs_to :entity, Entity

    timestamps()
  end

  def changeset(alias, attrs) do
    alias
    |> cast(attrs, [
      :entity_id,
      :alias,
      :normalized_alias,
      :first_seen_at,
      :last_seen_at,
      :confidence
    ])
    |> put_normalized_alias()
    |> validate_required([:entity_id, :alias, :normalized_alias])
    |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> foreign_key_constraint(:entity_id)
    |> unique_constraint([:entity_id, :normalized_alias])
  end

  defp put_normalized_alias(changeset) do
    case {get_field(changeset, :normalized_alias), get_field(changeset, :alias)} do
      {nil, value} when is_binary(value) ->
        put_change(changeset, :normalized_alias, normalize(value))

      {"", value} when is_binary(value) ->
        put_change(changeset, :normalized_alias, normalize(value))

      _ ->
        changeset
    end
  end

  defp normalize(value) do
    value
    |> String.downcase()
    |> String.trim()
  end
end
