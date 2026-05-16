defmodule StreamGenome.YouTube.ChannelImportTest do
  use StreamGenome.DataCase, async: true

  alias StreamGenome.YouTube.ChannelImport

  test "registers a handle channel url as a youtube source" do
    assert {:ok, source} = ChannelImport.register("https://www.youtube.com/@ExampleChannel")

    assert source.source_type == "youtube"
    assert source.name == "@ExampleChannel"
    assert source.external_id == "@examplechannel"
    assert source.url == "https://www.youtube.com/@ExampleChannel"
  end

  test "returns the existing source when the same channel is registered again" do
    assert {:ok, first} = ChannelImport.register("https://www.youtube.com/@ExampleChannel")
    assert {:ok, second} = ChannelImport.register("https://www.youtube.com/@ExampleChannel")

    assert first.id == second.id
  end

  test "rejects non-youtube urls" do
    assert {:error, :not_youtube} = ChannelImport.register("https://example.com/@ExampleChannel")
  end
end
