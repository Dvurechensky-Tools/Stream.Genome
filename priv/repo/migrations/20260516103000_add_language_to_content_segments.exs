defmodule StreamGenome.Repo.Migrations.AddLanguageToContentSegments do
  use Ecto.Migration

  def change do
    alter table(:content_segments) do
      add :language, :string
    end

    execute(
      """
      UPDATE content_segments
      SET language = 'ru'
      WHERE language IS NULL AND body ~ '[А-Яа-яЁё]'
      """,
      """
      UPDATE content_segments
      SET language = NULL
      WHERE language = 'ru'
      """
    )

    execute(
      """
      UPDATE content_segments
      SET language = 'en'
      WHERE language IS NULL AND body ~ '[A-Za-z]'
      """,
      """
      UPDATE content_segments
      SET language = NULL
      WHERE language = 'en'
      """
    )

    create index(:content_segments, [:language])
  end
end
