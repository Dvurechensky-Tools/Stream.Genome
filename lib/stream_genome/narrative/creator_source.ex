defmodule StreamGenome.Narrative.CreatorSource do
  @moduledoc """
  A creator-owned source such as a YouTube channel, Twitch channel, or Discord export.
  """

  use StreamGenome.Narrative.Schema

  alias StreamGenome.Narrative.{ContentItem, SourceScanRun, Types}

  schema "creator_sources" do
    field :name, :string
    field :source_type, :string
    field :external_id, :string
    field :url, :string
    field :metadata, :map, default: %{}

    has_many :content_items, ContentItem, foreign_key: :source_id
    has_many :scan_runs, SourceScanRun, foreign_key: :source_id

    timestamps()
  end

  def changeset(source, attrs) do
    source
    |> cast(attrs, [:name, :source_type, :external_id, :url, :metadata])
    |> validate_required([:name, :source_type])
    |> validate_inclusion(:source_type, Types.source_types())
    |> unique_constraint([:source_type, :external_id])
  end
end
