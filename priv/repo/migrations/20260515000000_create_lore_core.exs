defmodule StreamGenome.Repo.Migrations.CreateLoreCore do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm", "DROP EXTENSION IF EXISTS pg_trgm"

    create table(:creator_sources, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :source_type, :string, null: false
      add :external_id, :string
      add :url, :text
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:creator_sources, [:source_type, :external_id],
             where: "external_id IS NOT NULL"
           )

    create table(:content_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :source_id, references(:creator_sources, type: :binary_id, on_delete: :nilify_all)
      add :kind, :string, null: false
      add :external_id, :string
      add :title, :text
      add :url, :text
      add :published_at, :utc_datetime_usec
      add :duration_ms, :bigint
      add :language, :string
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create index(:content_items, [:source_id])
    create index(:content_items, [:published_at])

    create table(:content_segments, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :content_item_id, references(:content_items, type: :binary_id, on_delete: :delete_all),
        null: false

      add :segment_type, :string, null: false
      add :speaker_label, :string
      add :body, :text, null: false
      add :starts_at_ms, :bigint
      add :ends_at_ms, :bigint
      add :occurred_at, :utc_datetime_usec
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create index(:content_segments, [:content_item_id])
    create index(:content_segments, [:occurred_at])

    execute(
      "CREATE INDEX content_segments_body_trgm_index ON content_segments USING gin (body gin_trgm_ops)",
      "DROP INDEX content_segments_body_trgm_index"
    )

    create table(:narrative_entities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :entity_type, :string, null: false
      add :canonical_name, :string, null: false
      add :slug, :string, null: false
      add :summary, :text
      add :first_seen_at, :utc_datetime_usec
      add :last_seen_at, :utc_datetime_usec
      add :confidence, :float, null: false, default: 0.0
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:narrative_entities, [:slug])
    create index(:narrative_entities, [:entity_type])

    execute(
      "CREATE INDEX narrative_entities_canonical_name_trgm_index ON narrative_entities USING gin (canonical_name gin_trgm_ops)",
      "DROP INDEX narrative_entities_canonical_name_trgm_index"
    )

    create table(:entity_aliases, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :entity_id, references(:narrative_entities, type: :binary_id, on_delete: :delete_all),
        null: false

      add :alias, :string, null: false
      add :normalized_alias, :string, null: false
      add :first_seen_at, :utc_datetime_usec
      add :last_seen_at, :utc_datetime_usec
      add :confidence, :float, null: false, default: 0.0

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:entity_aliases, [:entity_id, :normalized_alias])
    create index(:entity_aliases, [:normalized_alias])

    create table(:entity_observations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :entity_id, references(:narrative_entities, type: :binary_id, on_delete: :delete_all),
        null: false

      add :content_segment_id,
          references(:content_segments, type: :binary_id, on_delete: :delete_all),
          null: false

      add :surface_text, :string, null: false
      add :observation_type, :string, null: false
      add :sentiment, :float
      add :emotion_score, :float
      add :confidence, :float, null: false, default: 0.0
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create index(:entity_observations, [:entity_id])
    create index(:entity_observations, [:content_segment_id])

    create table(:narrative_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_type, :string, null: false
      add :title, :string, null: false
      add :summary, :text
      add :started_at, :utc_datetime_usec
      add :ended_at, :utc_datetime_usec
      add :intensity, :float, null: false, default: 0.0
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create index(:narrative_events, [:event_type])
    create index(:narrative_events, [:started_at])

    create table(:narrative_edges, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :edge_type, :string, null: false

      add :from_entity_id,
          references(:narrative_entities, type: :binary_id, on_delete: :delete_all)

      add :to_entity_id, references(:narrative_entities, type: :binary_id, on_delete: :delete_all)
      add :event_id, references(:narrative_events, type: :binary_id, on_delete: :nilify_all)
      add :weight, :float, null: false, default: 1.0
      add :first_seen_at, :utc_datetime_usec
      add :last_seen_at, :utc_datetime_usec
      add :evidence, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create index(:narrative_edges, [:edge_type])
    create index(:narrative_edges, [:from_entity_id])
    create index(:narrative_edges, [:to_entity_id])
    create index(:narrative_edges, [:event_id])

    create table(:meme_evolutions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :meme_id, references(:narrative_entities, type: :binary_id, on_delete: :delete_all),
        null: false

      add :parent_meme_id,
          references(:narrative_entities, type: :binary_id, on_delete: :nilify_all)

      add :mutation_label, :string, null: false
      add :first_seen_at, :utc_datetime_usec
      add :last_seen_at, :utc_datetime_usec
      add :popularity_score, :float, null: false, default: 0.0
      add :status, :string, null: false, default: "emerging"
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create index(:meme_evolutions, [:meme_id])
    create index(:meme_evolutions, [:parent_meme_id])
    create index(:meme_evolutions, [:status])
  end
end
