defmodule StreamGenome.Repo.Migrations.CreateNarrativeLocalizations do
  use Ecto.Migration

  def change do
    create table(:entity_localizations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :entity_id, references(:narrative_entities, type: :binary_id, on_delete: :delete_all),
        null: false

      add :language, :string, null: false
      add :display_name, :string, null: false
      add :summary, :text
      add :context_note, :text
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:entity_localizations, [:entity_id, :language])
    create index(:entity_localizations, [:language])

    create table(:event_localizations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :event_id, references(:narrative_events, type: :binary_id, on_delete: :delete_all),
        null: false

      add :language, :string, null: false
      add :title, :string, null: false
      add :summary, :text
      add :context_note, :text
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:event_localizations, [:event_id, :language])
    create index(:event_localizations, [:language])
  end
end
