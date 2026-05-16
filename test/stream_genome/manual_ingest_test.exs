defmodule StreamGenome.ManualIngestTest do
  use StreamGenome.DataCase, async: true

  alias StreamGenome.ManualIngest
  alias StreamGenome.Narrative

  test "ingests pasted stream lines into the lore ledger" do
    assert {:ok, result} =
             ManualIngest.ingest("""
             Streamer: Chair arc returns tonight.
             Chat: CHAIR ARC RETURNS
             Streamer: Chair arc returns as a retired villain.
             """)

    assert length(result.segments) == 3
    assert length(result.speakers) == 2
    assert result.event.title == "Manual Fragment Ingested"

    snapshot = Narrative.dashboard_snapshot()
    assert snapshot.counts.segments == 3
    assert Enum.any?(snapshot.entities, &(&1.canonical_name == "Streamer"))
  end

  test "rejects empty pasted text" do
    assert {:error, :empty_text} = ManualIngest.ingest("   \n  ")
  end
end
