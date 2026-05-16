defmodule StreamGenome.Intelligence.ExtractionRun do
  @moduledoc """
  A durable AI-analysis window built from transcript segments.
  """

  use StreamGenome.Narrative.Schema

  alias StreamGenome.Narrative.{ContentItem, CreatorSource}

  @tasks ~w(lore_extraction callback_detection localization)
  @statuses ~w(queued awaiting_model completed failed)

  schema "intelligence_extraction_runs" do
    field :task, :string
    field :status, :string, default: "queued"
    field :language, :string, default: "unknown"
    field :segment_ids, {:array, :binary_id}, default: []
    field :input_text, :string
    field :prompt, :string
    field :result, :map
    field :error_message, :string
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec
    field :metadata, :map, default: %{}

    belongs_to :source, CreatorSource
    belongs_to :content_item, ContentItem

    timestamps()
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :source_id,
      :content_item_id,
      :task,
      :status,
      :language,
      :segment_ids,
      :input_text,
      :prompt,
      :result,
      :error_message,
      :started_at,
      :finished_at,
      :metadata
    ])
    |> validate_required([
      :source_id,
      :task,
      :status,
      :language,
      :segment_ids,
      :input_text,
      :prompt
    ])
    |> validate_inclusion(:task, @tasks)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:source_id)
    |> foreign_key_constraint(:content_item_id)
  end
end
