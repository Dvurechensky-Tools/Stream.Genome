defmodule StreamGenome.Repo.Migrations.CreateSourceScanRuns do
  use Ecto.Migration

  def change do
    create table(:source_scan_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :source_id, references(:creator_sources, type: :binary_id, on_delete: :delete_all),
        null: false

      add :status, :string, null: false, default: "queued"
      add :requested_by, :string, null: false, default: "admin"
      add :started_at, :utc_datetime_usec
      add :finished_at, :utc_datetime_usec
      add :items_discovered, :integer, null: false, default: 0
      add :items_enqueued, :integer, null: false, default: 0
      add :error_message, :text
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create index(:source_scan_runs, [:source_id])
    create index(:source_scan_runs, [:status])
    create index(:source_scan_runs, [:inserted_at])
  end
end
