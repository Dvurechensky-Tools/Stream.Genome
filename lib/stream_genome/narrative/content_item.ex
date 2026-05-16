defmodule StreamGenome.Narrative.ContentItem do
  @moduledoc """
  A durable input unit: stream, clip, podcast episode, thread, or exported chat.
  """

  use StreamGenome.Narrative.Schema

  alias StreamGenome.Narrative.{ContentSegment, CreatorSource, Types}

  schema "content_items" do
    field :kind, :string
    field :external_id, :string
    field :title, :string
    field :url, :string
    field :published_at, :utc_datetime_usec
    field :duration_ms, :integer
    field :language, :string
    field :metadata, :map, default: %{}

    belongs_to :source, CreatorSource
    has_many :segments, ContentSegment

    timestamps()
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :source_id,
      :kind,
      :external_id,
      :title,
      :url,
      :published_at,
      :duration_ms,
      :language,
      :metadata
    ])
    |> validate_required([:kind])
    |> validate_inclusion(:kind, Types.content_kinds())
    |> foreign_key_constraint(:source_id)
  end
end
