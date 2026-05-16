defmodule StreamGenome.Narrative.ContentSegment do
  @moduledoc """
  Time-addressable text extracted from transcripts, chat logs, OCR, comments, or metadata.
  """

  use StreamGenome.Narrative.Schema

  alias StreamGenome.Narrative.{ContentItem, EntityObservation, Types}

  schema "content_segments" do
    field :segment_type, :string
    field :speaker_label, :string
    field :body, :string
    field :language, :string
    field :starts_at_ms, :integer
    field :ends_at_ms, :integer
    field :occurred_at, :utc_datetime_usec
    field :metadata, :map, default: %{}

    belongs_to :content_item, ContentItem
    has_many :observations, EntityObservation

    timestamps()
  end

  def changeset(segment, attrs) do
    segment
    |> cast(attrs, [
      :content_item_id,
      :segment_type,
      :speaker_label,
      :body,
      :language,
      :starts_at_ms,
      :ends_at_ms,
      :occurred_at,
      :metadata
    ])
    |> validate_required([:content_item_id, :segment_type, :body])
    |> validate_inclusion(:segment_type, Types.segment_types())
    |> validate_number(:starts_at_ms, greater_than_or_equal_to: 0)
    |> validate_number(:ends_at_ms, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:content_item_id)
  end
end
