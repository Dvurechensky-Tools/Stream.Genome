defmodule StreamGenome.Narrative.NarrativeEvent do
  @moduledoc """
  A time-bounded lore event, callback, conflict, revival, or arc turn.
  """

  use StreamGenome.Narrative.Schema

  alias StreamGenome.Narrative.{EventLocalization, NarrativeEdge, Types}

  schema "narrative_events" do
    field :event_type, :string
    field :title, :string
    field :summary, :string
    field :started_at, :utc_datetime_usec
    field :ended_at, :utc_datetime_usec
    field :intensity, :float, default: 0.0
    field :metadata, :map, default: %{}

    has_many :edges, NarrativeEdge, foreign_key: :event_id
    has_many :localizations, EventLocalization, foreign_key: :event_id

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:event_type, :title, :summary, :started_at, :ended_at, :intensity, :metadata])
    |> validate_required([:event_type, :title])
    |> validate_inclusion(:event_type, Types.event_types())
    |> validate_number(:intensity, greater_than_or_equal_to: 0.0)
  end
end
