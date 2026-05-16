defmodule StreamGenome.Narrative.EntityTest do
  use ExUnit.Case, async: true

  alias StreamGenome.Narrative.Entity

  test "changeset derives a stable slug" do
    changeset =
      Entity.changeset(%Entity{}, %{
        entity_type: "meme",
        canonical_name: "The Chair Incident",
        confidence: 0.8
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_change(changeset, :slug) == "the-chair-incident"
  end

  test "changeset rejects unknown entity types" do
    changeset =
      Entity.changeset(%Entity{}, %{
        entity_type: "recommendation_target",
        canonical_name: "Nope"
      })

    refute changeset.valid?
  end
end
