defmodule StreamGenome.Narrative.EventLocalization do
  @moduledoc """
  Localized public-facing copy for a narrative event.
  """

  use StreamGenome.Narrative.Schema

  alias StreamGenome.Narrative.NarrativeEvent

  schema "event_localizations" do
    field :language, :string
    field :title, :string
    field :summary, :string
    field :context_note, :string
    field :metadata, :map, default: %{}

    belongs_to :event, NarrativeEvent

    timestamps()
  end

  def changeset(localization, attrs) do
    localization
    |> cast(attrs, [:event_id, :language, :title, :summary, :context_note, :metadata])
    |> validate_required([:event_id, :language, :title])
    |> foreign_key_constraint(:event_id)
    |> unique_constraint([:event_id, :language])
  end
end
