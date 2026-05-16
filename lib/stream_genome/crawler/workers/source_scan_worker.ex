defmodule StreamGenome.Crawler.Workers.SourceScanWorker do
  @moduledoc """
  Discovers source items and stores them as content items.
  """

  use Oban.Worker, queue: :crawler, max_attempts: 3

  alias StreamGenome.Narrative
  alias StreamGenome.Narrative.{ContentItem, SourceScanRun}
  alias StreamGenome.Repo
  alias StreamGenome.YouTube.VideoDiscovery

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"scan_run_id" => scan_run_id}}) do
    scan_run = Repo.get!(SourceScanRun, scan_run_id)
    now = DateTime.utc_now()

    {:ok, scan_run} =
      Narrative.update_source_scan_run(scan_run, %{
        status: "running",
        started_at: now
      })

    scan_run = Repo.preload(scan_run, :source)

    case discover(scan_run.source) do
      {:ok, discovery} ->
        created_count = store_videos(scan_run.source, discovery.videos)
        maybe_cache_channel_id(scan_run.source, discovery.channel_id)

        Narrative.update_source_scan_run(scan_run, %{
          status: "completed",
          finished_at: DateTime.utc_now(),
          items_discovered: length(discovery.videos),
          items_enqueued: created_count,
          metadata:
            Map.merge(scan_run.metadata || %{}, %{
              crawler_state: crawler_state(discovery),
              discovery_adapter: Map.get(discovery, :adapter),
              archive_limit: Map.get(discovery, :archive_limit),
              channel_id: discovery.channel_id,
              feed_locator: inspect(discovery.feed_locator),
              feed_url: discovery.feed_url,
              archive_error: Map.get(discovery, :archive_error),
              proxy: VideoDiscovery.proxy_label(),
              next_step: "queue transcript discovery per video"
            })
        })

      {:error, reason} ->
        Narrative.update_source_scan_run(scan_run, %{
          status: "failed",
          finished_at: DateTime.utc_now(),
          error_message: VideoDiscovery.describe_error(reason),
          metadata:
            Map.merge(scan_run.metadata || %{}, %{
              crawler_state: "video_feed_discovery_failed",
              failure_reason: inspect(reason),
              proxy: VideoDiscovery.proxy_label()
            })
        })
    end

    :ok
  end

  defp discover(%{source_type: "youtube"} = source), do: VideoDiscovery.discover(source)
  defp discover(source), do: {:error, {:unsupported_source_type, source.source_type}}

  defp crawler_state(%{adapter: "youtube_yt_dlp_archive"}), do: "video_archive_discovered"
  defp crawler_state(_discovery), do: "video_feed_discovered"

  defp store_videos(source, videos) do
    videos
    |> Enum.map(fn video ->
      case Narrative.get_content_item_by_source_external(source.id, video.external_id) do
        %ContentItem{} ->
          :existing

        nil ->
          {:ok, _item} =
            Narrative.create_content_item(%{
              source_id: source.id,
              kind: "video",
              external_id: video.external_id,
              title: video.title,
              url: video.url,
              published_at: video.published_at,
              metadata: %{
                youtube_author: video.author,
                youtube_updated_at: video.updated_at,
                discovery: video[:discovery] || "youtube_video_discovery"
              }
            })

          :created
      end
    end)
    |> Enum.count(&(&1 == :created))
  end

  defp maybe_cache_channel_id(_source, nil), do: :ok

  defp maybe_cache_channel_id(source, channel_id) do
    metadata = Map.put(source.metadata || %{}, "youtube_channel_id", channel_id)
    Narrative.update_source(source, %{metadata: metadata})
    :ok
  end
end
