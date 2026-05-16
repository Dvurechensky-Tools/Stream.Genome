defmodule StreamGenomeWeb.AdminSourceController do
  use StreamGenomeWeb, :controller

  alias StreamGenome.Narrative
  alias StreamGenome.Intelligence

  def show(conn, %{"id" => id}) do
    source = Narrative.get_source_with_scan_runs!(id)

    render(conn, :show,
      page_title: "#{source.name} Source",
      meta_description: "Operational source status for Stream.Genome.",
      source: source,
      transcript_snapshot: Narrative.source_transcript_snapshot(source.id),
      intelligence_snapshot: Intelligence.source_snapshot(source.id),
      lore_snapshot: Narrative.source_lore_snapshot(source.id),
      ai_settings: StreamGenome.AI.settings()
    )
  end

  def scan(conn, %{"id" => id}) do
    case Narrative.start_source_scan(id) do
      {:ok, _scan_run} ->
        conn
        |> put_flash(:info, "Scan queued.")
        |> redirect(to: ~p"/admin/sources/#{id}")

      {:error, :source_not_found} ->
        conn
        |> put_flash(:error, "Source not found.")
        |> redirect(to: ~p"/admin")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Scan could not be queued.")
        |> redirect(to: ~p"/admin/sources/#{id}")
    end
  end

  def transcripts(conn, %{"id" => id} = params) do
    limit = parse_limit(params, 50)

    {:ok, %{videos: videos}} = Narrative.queue_source_transcripts(id, limit: limit)

    conn
    |> put_flash(:info, "Queued transcript discovery for #{length(videos)} videos.")
    |> redirect(to: ~p"/admin/sources/#{id}")
  end

  def retry_failed_transcripts(conn, %{"id" => id} = params) do
    limit = parse_limit(params, 10)
    {:ok, %{videos: videos}} = Narrative.retry_failed_source_transcripts(id, limit: limit)

    conn
    |> put_flash(:info, "Requeued #{length(videos)} failed transcript jobs.")
    |> redirect(to: ~p"/admin/sources/#{id}")
  end

  def intelligence_windows(conn, %{"id" => id} = params) do
    limit = parse_limit(params, 5)
    {:ok, %{runs: runs}} = Intelligence.queue_source_extraction_windows(id, limit: limit)

    conn
    |> put_flash(:info, "Queued #{length(runs)} AI extraction windows.")
    |> redirect(to: ~p"/admin/sources/#{id}")
  end

  def project_intelligence(conn, %{"id" => id} = params) do
    limit = parse_limit(params, 10)
    {:ok, %{runs: runs}} = Intelligence.project_completed_source_runs(id, limit: limit)

    conn
    |> put_flash(:info, "Projected #{length(runs)} completed AI runs into lore graph.")
    |> redirect(to: ~p"/admin/sources/#{id}")
  end

  def auto_intelligence(conn, %{"id" => id} = params) do
    window_count = parse_limit(Map.get(params, "batch", %{}), "windows", 5)
    batches = parse_limit(Map.get(params, "batch", %{}), "count", 20)

    case Intelligence.start_source_ai_autobatch(id, window_count: window_count, batches: batches) do
      {:ok, _job} ->
        conn
        |> put_flash(:info, "Auto AI batches started: #{batches} x #{window_count}.")
        |> redirect(to: ~p"/admin/sources/#{id}")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Auto AI batches could not be started.")
        |> redirect(to: ~p"/admin/sources/#{id}")
    end
  end

  def auto_transcripts(conn, %{"id" => id} = params) do
    batch_size = parse_limit(Map.get(params, "batch", %{}), "size", 5)
    batches = parse_limit(Map.get(params, "batch", %{}), "count", 20)

    case Narrative.start_source_transcript_autobatch(id, batch_size: batch_size, batches: batches) do
      {:ok, _job} ->
        conn
        |> put_flash(:info, "Auto transcript batches started: #{batches} x #{batch_size}.")
        |> redirect(to: ~p"/admin/sources/#{id}")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Auto transcript batches could not be started.")
        |> redirect(to: ~p"/admin/sources/#{id}")
    end
  end

  defp parse_limit(params, default) do
    parse_limit(params, "limit", default)
  end

  defp parse_limit(params, key, default) do
    params
    |> Map.get(key, Integer.to_string(default))
    |> Integer.parse()
    |> case do
      {value, ""} when value > 0 -> value
      _other -> default
    end
  end
end
