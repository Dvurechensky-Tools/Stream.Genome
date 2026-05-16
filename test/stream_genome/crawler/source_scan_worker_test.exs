defmodule StreamGenome.Crawler.SourceScanWorkerTest do
  use StreamGenome.DataCase, async: true

  alias StreamGenome.Crawler.Workers.SourceScanWorker
  alias StreamGenome.Narrative

  test "discovers youtube feed videos and stores content items" do
    feed_xml = """
    <feed xmlns:yt="http://www.youtube.com/xml/schemas/2015">
      <entry>
        <yt:videoId>abc123</yt:videoId>
        <title>First Video</title>
        <published>2026-05-15T10:20:30+00:00</published>
        <updated>2026-05-15T11:20:30+00:00</updated>
        <author><name>Example Channel</name></author>
      </entry>
      <entry>
        <yt:videoId>def456</yt:videoId>
        <title>Second Video</title>
        <published>2026-05-16T10:20:30+00:00</published>
        <updated>2026-05-16T11:20:30+00:00</updated>
        <author><name>Example Channel</name></author>
      </entry>
    </feed>
    """

    {:ok, source} =
      Narrative.create_source(%{
        name: "@ExampleChannel",
        source_type: "youtube",
        external_id: "UC123abc",
        url: "https://www.youtube.com/channel/UC123abc",
        metadata: %{"feed_xml" => feed_xml}
      })

    {:ok, scan_run} =
      Narrative.create_source_scan_run(%{
        source_id: source.id,
        status: "queued"
      })

    assert :ok = SourceScanWorker.perform(%Oban.Job{args: %{"scan_run_id" => scan_run.id}})

    source = Narrative.get_source_with_scan_runs!(source.id)
    [completed] = source.scan_runs

    assert completed.status == "completed"
    assert completed.items_discovered == 2
    assert completed.items_enqueued == 2
    assert completed.metadata["crawler_state"] == "video_feed_discovered"

    assert Narrative.get_content_item_by_source_external(source.id, "abc123")
    assert Narrative.get_content_item_by_source_external(source.id, "def456")
  end
end
