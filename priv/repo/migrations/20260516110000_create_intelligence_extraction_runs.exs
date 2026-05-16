defmodule StreamGenome.Repo.Migrations.CreateIntelligenceExtractionRuns do
  use Ecto.Migration

  def change do
    create table(:intelligence_extraction_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :source_id, references(:creator_sources, type: :binary_id, on_delete: :delete_all)
      add :content_item_id, references(:content_items, type: :binary_id, on_delete: :delete_all)
      add :task, :string, null: false
      add :status, :string, null: false, default: "queued"
      add :language, :string, null: false, default: "unknown"
      add :segment_ids, {:array, :binary_id}, null: false, default: []
      add :input_text, :text, null: false
      add :prompt, :text, null: false
      add :result, :map
      add :error_message, :text
      add :started_at, :utc_datetime_usec
      add :finished_at, :utc_datetime_usec
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create index(:intelligence_extraction_runs, [:source_id])
    create index(:intelligence_extraction_runs, [:content_item_id])
    create index(:intelligence_extraction_runs, [:status])
    create index(:intelligence_extraction_runs, [:language])
  end
end
