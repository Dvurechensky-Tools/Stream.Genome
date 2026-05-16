defmodule StreamGenomeWeb.AdminController do
  use StreamGenomeWeb, :controller

  alias StreamGenome.Crawler
  alias StreamGenome.Narrative

  def index(conn, _params) do
    render(conn, :index,
      page_title: "Admin Console",
      meta_description: "Operational source and ingestion controls for Stream.Genome.",
      crawler_settings: Crawler.get_network_settings(),
      cookies_status: Crawler.cookies_status(),
      ai_settings: StreamGenome.AI.form_settings(),
      ai_runtime: StreamGenome.AI.settings(),
      proxy_label: Crawler.proxy_label(),
      snapshot: Narrative.dashboard_snapshot()
    )
  end

  def update_crawler_settings(conn, %{"crawler_settings" => settings}) do
    case Crawler.update_network_settings(settings) do
      {:ok, _setting} ->
        conn
        |> put_flash(:info, "Crawler network settings saved.")
        |> redirect(to: ~p"/admin")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Crawler network settings could not be saved.")
        |> redirect(to: ~p"/admin")
    end
  end

  def update_ai_settings(conn, %{"ai_settings" => settings}) do
    case StreamGenome.AI.update_settings(settings) do
      {:ok, _setting} ->
        conn
        |> put_flash(:info, "AI provider settings saved.")
        |> redirect(to: ~p"/admin")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "AI provider settings could not be saved.")
        |> redirect(to: ~p"/admin")
    end
  end

  def save_youtube_cookies(conn, %{"youtube_cookies" => attrs}) do
    case Crawler.save_youtube_cookies(attrs) do
      {:ok, _setting} ->
        conn
        |> put_flash(:info, "YouTube cookies saved.")
        |> redirect(to: ~p"/admin")

      {:error, :empty_cookies} ->
        conn
        |> put_flash(:error, "Paste cookies.txt content first.")
        |> redirect(to: ~p"/admin")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "YouTube cookies could not be saved.")
        |> redirect(to: ~p"/admin")
    end
  end
end
