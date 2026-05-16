defmodule StreamGenome.Repo.Migrations.CreateCrawlerSettings do
  use Ecto.Migration

  def change do
    create table(:crawler_settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :value, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:crawler_settings, [:key])
  end
end
