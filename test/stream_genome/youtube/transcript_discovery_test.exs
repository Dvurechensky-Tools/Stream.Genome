defmodule StreamGenome.YouTube.TranscriptDiscoveryTest do
  use ExUnit.Case, async: true

  alias StreamGenome.YouTube.TranscriptDiscovery

  test "parses vtt cues into transcript segments" do
    vtt = """
    WEBVTT

    00:00:01.000 --> 00:00:03.500
    Привет <c>чат</c>

    00:00:04.000 --> 00:00:05.000
    второй кусок
    """

    assert [
             %{body: "Привет чат", starts_at_ms: 1000, ends_at_ms: 3500},
             %{body: "второй кусок", starts_at_ms: 4000, ends_at_ms: 5000}
           ] = TranscriptDiscovery.parse_vtt(vtt)
  end
end
