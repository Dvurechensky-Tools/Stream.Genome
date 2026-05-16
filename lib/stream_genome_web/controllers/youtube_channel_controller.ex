defmodule StreamGenomeWeb.YouTubeChannelController do
  use StreamGenomeWeb, :controller

  alias StreamGenome.YouTube.ChannelImport

  def new(conn, _params) do
    render(conn, :new, url: "")
  end

  def create(conn, %{"youtube_channel" => %{"url" => url}}) do
    case ChannelImport.register(url) do
      {:ok, source} ->
        conn
        |> put_flash(:info, "YouTube channel registered: #{source.name}")
        |> redirect(to: ~p"/admin/sources/#{source.id}")

      {:error, reason} ->
        conn
        |> put_flash(:error, error_message(reason))
        |> render(:new, url: url)
    end
  end

  defp error_message(:not_youtube), do: "Paste a YouTube channel URL."

  defp error_message(:missing_channel),
    do: "Use a channel URL like https://www.youtube.com/@channel."

  defp error_message(:invalid_url), do: "Paste a valid YouTube channel URL."
end
