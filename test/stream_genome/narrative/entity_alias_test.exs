defmodule StreamGenome.Narrative.EntityAliasTest do
  use ExUnit.Case, async: true

  alias StreamGenome.Narrative.EntityAlias

  test "changeset normalizes aliases" do
    changeset =
      EntityAlias.changeset(%EntityAlias{}, %{
        entity_id: Ecto.UUID.generate(),
        alias: "  Chair Arc  ",
        confidence: 0.7
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_change(changeset, :normalized_alias) == "chair arc"
  end
end
