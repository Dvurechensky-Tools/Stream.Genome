defmodule StreamGenome.Narrative.EntityLocalization do
  @moduledoc """
  Localized public-facing copy for a narrative entity.
  """

  use StreamGenome.Narrative.Schema

  alias StreamGenome.Narrative.Entity

  schema "entity_localizations" do
    field :language, :string
    field :display_name, :string
    field :summary, :string
    field :context_note, :string
    field :metadata, :map, default: %{}

    belongs_to :entity, Entity

    timestamps()
  end

  def changeset(localization, attrs) do
    localization
    |> cast(attrs, [:entity_id, :language, :display_name, :summary, :context_note, :metadata])
    |> validate_required([:entity_id, :language, :display_name])
    |> foreign_key_constraint(:entity_id)
    |> unique_constraint([:entity_id, :language])
  end
end
