defmodule StreamGenome.YouTube.ChannelImport do
  @moduledoc """
  Registers a YouTube channel as a real-world source.

  This is the first step before fetching videos, transcripts, comments, and chat.
  """

  alias StreamGenome.Narrative
  alias StreamGenome.Narrative.CreatorSource
  alias StreamGenome.Repo

  def register(url) when is_binary(url) do
    url = String.trim(url)

    with {:ok, parsed} <- parse_url(url) do
      source =
        Repo.get_by(CreatorSource, source_type: "youtube", external_id: parsed.external_id) ||
          create_source!(parsed)

      {:ok, source}
    end
  end

  def register(_), do: {:error, :invalid_url}

  def parse_url(url) when is_binary(url) do
    uri = URI.parse(url)
    host = uri.host && String.downcase(uri.host)

    cond do
      host not in ["youtube.com", "www.youtube.com", "m.youtube.com"] ->
        {:error, :not_youtube}

      is_nil(uri.path) or uri.path == "/" ->
        {:error, :missing_channel}

      true ->
        parse_path(url, uri.path)
    end
  end

  defp parse_path(url, path) do
    parts = path |> String.trim("/") |> String.split("/", trim: true)

    case parts do
      ["@" <> handle | _] ->
        {:ok,
         %{
           name: "@#{handle}",
           external_id: "@#{String.downcase(handle)}",
           url: canonical_url("@#{handle}"),
           metadata: %{kind: "handle", original_url: url}
         }}

      ["channel", channel_id | _] ->
        {:ok,
         %{
           name: channel_id,
           external_id: channel_id,
           url: "https://www.youtube.com/channel/#{channel_id}",
           metadata: %{kind: "channel_id", original_url: url}
         }}

      [kind, name | _] when kind in ["c", "user"] ->
        {:ok,
         %{
           name: name,
           external_id: "#{kind}:#{String.downcase(name)}",
           url: "https://www.youtube.com/#{kind}/#{name}",
           metadata: %{kind: kind, original_url: url}
         }}

      _ ->
        {:error, :missing_channel}
    end
  end

  defp create_source!(parsed) do
    {:ok, source} =
      Narrative.create_source(%{
        name: parsed.name,
        source_type: "youtube",
        external_id: parsed.external_id,
        url: parsed.url,
        metadata: Map.put(parsed.metadata, :registered_by, "manual_channel_import")
      })

    source
  end

  defp canonical_url("@" <> _ = handle), do: "https://www.youtube.com/#{handle}"
end
