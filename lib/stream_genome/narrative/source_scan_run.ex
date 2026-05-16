defmodule StreamGenome.Narrative.SourceScanRun do
  @moduledoc """
  One operational crawl attempt for a registered creator source.
  """

  use StreamGenome.Narrative.Schema

  alias StreamGenome.Narrative.CreatorSource

  @statuses ~w(queued running completed failed cancelled)

  schema "source_scan_runs" do
    field :status, :string, default: "queued"
    field :requested_by, :string, default: "admin"
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec
    field :items_discovered, :integer, default: 0
    field :items_enqueued, :integer, default: 0
    field :error_message, :string
    field :metadata, :map, default: %{}

    belongs_to :source, CreatorSource

    timestamps()
  end

  def changeset(scan_run, attrs) do
    scan_run
    |> cast(attrs, [
      :source_id,
      :status,
      :requested_by,
      :started_at,
      :finished_at,
      :items_discovered,
      :items_enqueued,
      :error_message,
      :metadata
    ])
    |> validate_required([:source_id, :status, :requested_by])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:items_discovered, greater_than_or_equal_to: 0)
    |> validate_number(:items_enqueued, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:source_id)
  end
end
