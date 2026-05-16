defmodule StreamGenome.Repo.Migrations.RemovePlaceholderIntelligenceEvents do
  use Ecto.Migration

  def up do
    execute """
    DELETE FROM narrative_events
    WHERE title = 'Unprocessed intelligence segment'
       OR metadata->>'status' = 'awaiting_model'
    """
  end

  def down do
    :ok
  end
end
