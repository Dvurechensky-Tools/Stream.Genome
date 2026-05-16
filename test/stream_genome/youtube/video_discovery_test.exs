defmodule StreamGenome.YouTube.VideoDiscoveryTest do
  use ExUnit.Case, async: true

  alias StreamGenome.YouTube.VideoDiscovery

  test "parses channel id from youtube html" do
    assert {:ok, "UC123abc_XYZ"} =
             VideoDiscovery.parse_channel_id(~s({"channelId":"UC123abc_XYZ"}))
  end

  test "parses atom feed entries" do
    feed = """
    <feed xmlns:yt="http://www.youtube.com/xml/schemas/2015">
      <entry>
        <yt:videoId>abc123</yt:videoId>
        <title>First &amp; Best Video</title>
        <published>2026-05-15T10:20:30+00:00</published>
        <updated>2026-05-15T11:20:30+00:00</updated>
        <author><name>Example Channel</name></author>
      </entry>
    </feed>
    """

    assert {:ok, [video]} = VideoDiscovery.parse_feed(feed)
    assert video.external_id == "abc123"
    assert video.title == "First & Best Video"
    assert video.url == "https://www.youtube.com/watch?v=abc123"
    assert video.author == "Example Channel"
    assert video.published_at.year == 2026
  end

  test "adds configured proxy to request options" do
    Application.put_env(:stream_genome, :youtube_crawler,
      proxy: [scheme: :http, host: "127.0.0.1", port: 10808]
    )

    assert VideoDiscovery.request_options("https://www.youtube.com")
           |> Keyword.fetch!(:proxy) == {:http, "127.0.0.1", 10808, []}
  after
    Application.delete_env(:stream_genome, :youtube_crawler)
  end
end
