defmodule StreamGenome.YouTube.VideoDiscovery do
  @moduledoc """
  Discovers recent videos for a registered YouTube source through public channel pages and Atom feeds.
  """

  alias StreamGenome.Narrative.CreatorSource
  alias StreamGenome.Crawler

  @feed_base "https://www.youtube.com/feeds/videos.xml"
  @receive_timeout 30_000

  def proxy_label do
    case crawler_proxy() do
      nil ->
        "direct"

      false ->
        "direct"

      proxy ->
        scheme = proxy |> Keyword.get(:scheme, :http) |> Atom.to_string()
        host = Keyword.get(proxy, :host)
        port = Keyword.get(proxy, :port)

        "#{scheme}://#{host}:#{port}"
    end
  end

  def describe_error({:channel_page_request_failed, details}) when is_map(details) do
    "YouTube channel page request failed through #{details.proxy}: #{details.reason}"
  end

  def describe_error({:feed_request_failed, details}) when is_map(details) do
    "YouTube feed request failed through #{details.proxy}: #{details.reason}"
  end

  def describe_error({:feed_http_status, status, url}) do
    "YouTube feed returned HTTP #{status}: #{url}"
  end

  def describe_error({:channel_page_http_status, status, url}) do
    "YouTube channel page returned HTTP #{status}: #{url}"
  end

  def describe_error({:feed_empty, locator}) do
    "YouTube Atom feed was reachable but returned zero videos for #{inspect(locator)}"
  end

  def describe_error({:yt_dlp_failed, details}) when is_map(details) do
    "yt-dlp archive discovery failed with exit #{details.exit_status}: #{details.output}"
  end

  def describe_error({:yt_dlp_not_found, executable}) do
    "yt-dlp executable was not found: #{executable}"
  end

  def describe_error(:yt_dlp_returned_no_videos) do
    "yt-dlp archive discovery returned zero videos; check the yt-dlp executable/path"
  end

  def describe_error(reason), do: inspect(reason)

  def discover(%CreatorSource{} = source) do
    case discovery_adapter(source) do
      :yt_dlp -> discover_with_archive_fallback(source)
      _adapter -> discover_atom_feed(source)
    end
  end

  defp discover_with_archive_fallback(source) do
    case discover_archive(source) do
      {:ok, %{videos: [_video | _]} = discovery} ->
        {:ok, discovery}

      {:ok, %{videos: []}} ->
        discover_atom_feed_with_archive_error(source, :yt_dlp_returned_no_videos)

      {:error, reason} ->
        discover_atom_feed_with_archive_error(source, reason)
    end
  end

  defp discover_atom_feed_with_archive_error(source, archive_error) do
    case discover_atom_feed(source) do
      {:ok, discovery} -> {:ok, Map.put(discovery, :archive_error, describe_error(archive_error))}
      error -> error
    end
  end

  defp discover_atom_feed(source) do
    with {:ok, locator} <- resolve_feed_locator(source),
         {:ok, feed_xml} <- fetch_feed(source, locator),
         {:ok, videos} <- parse_feed(feed_xml) do
      {:ok,
       %{
         adapter: "youtube_atom_feed",
         channel_id: locator_channel_id(locator),
         feed_locator: locator,
         videos: videos,
         feed_url: feed_url(locator)
       }}
    end
  end

  defp discover_archive(source) do
    url = archive_url(source)
    limit = archive_limit()
    executable = yt_dlp_path()

    args =
      [
        "--flat-playlist",
        "--dump-json",
        "--no-warnings",
        "--playlist-end",
        Integer.to_string(limit)
      ] ++ cookies_args() ++ js_runtime_args() ++ proxy_args() ++ [url]

    case System.cmd(executable, args, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok,
         %{
           adapter: "youtube_yt_dlp_archive",
           archive_limit: limit,
           channel_id: source.metadata["youtube_channel_id"],
           feed_locator: {:yt_dlp_archive, url, limit: limit},
           videos: parse_yt_dlp_lines(output),
           feed_url: url
         }}

      {output, exit_status} ->
        {:error,
         {:yt_dlp_failed,
          %{url: url, proxy: proxy_label(), exit_status: exit_status, output: String.trim(output)}}}
    end
  rescue
    ErlangError ->
      {:error, {:yt_dlp_not_found, yt_dlp_path()}}
  end

  def parse_feed(feed_xml) when is_binary(feed_xml) do
    videos =
      ~r/<entry\b[^>]*>(.*?)<\/entry>/s
      |> Regex.scan(feed_xml)
      |> Enum.map(fn [_entry, body] -> parse_entry(body) end)
      |> Enum.reject(&is_nil/1)

    {:ok, videos}
  end

  def parse_channel_id(html) when is_binary(html) do
    patterns = [
      ~r/"channelId"\s*:\s*"(UC[^"]+)"/,
      ~r/<meta\s+itemprop="channelId"\s+content="(UC[^"]+)"/,
      ~r/\/channel\/(UC[[:alnum:]_-]+)/
    ]

    patterns
    |> Enum.find_value(fn pattern ->
      case Regex.run(pattern, html) do
        [_match, channel_id] -> channel_id
        _ -> nil
      end
    end)
    |> case do
      nil -> {:error, :channel_id_not_found}
      channel_id -> {:ok, channel_id}
    end
  end

  defp resolve_feed_locator(source) do
    cond do
      is_binary(source.metadata["youtube_channel_id"]) ->
        {:ok, {:channel_id, source.metadata["youtube_channel_id"]}}

      is_binary(source.external_id) and String.starts_with?(source.external_id, "UC") ->
        {:ok, {:channel_id, source.external_id}}

      is_binary(source.url) and String.contains?(source.url, "/channel/UC") ->
        source.url
        |> URI.parse()
        |> Map.get(:path)
        |> String.split("/", trim: true)
        |> case do
          ["channel", channel_id | _] -> {:ok, {:channel_id, channel_id}}
          _ -> fallback_feed_locator(source, :channel_id_not_found)
        end

      true ->
        case fetch_channel_page(source) do
          {:ok, channel_id} -> {:ok, {:channel_id, channel_id}}
          {:error, reason} -> fallback_feed_locator(source, reason)
        end
    end
  end

  defp fetch_channel_page(%{url: url}) when is_binary(url) do
    case request(url) do
      {:ok, %{status: status, body: body}} when status in 200..299 and is_binary(body) ->
        parse_channel_id(body)

      {:ok, %{status: status}} ->
        {:error, {:channel_page_http_status, status, url}}

      {:error, reason} ->
        {:error,
         {:channel_page_request_failed,
          %{url: url, proxy: proxy_label(), reason: inspect(reason)}}}
    end
  end

  defp fetch_channel_page(_source), do: {:error, :missing_channel_url}

  defp fallback_feed_locator(source, reason) do
    case handle_candidate(source) do
      nil -> {:error, reason}
      handle -> {:ok, {:user, handle, fallback_reason: reason}}
    end
  end

  defp handle_candidate(source) do
    cond do
      is_binary(source.external_id) and String.starts_with?(source.external_id, "@") ->
        source.external_id |> String.trim_leading("@") |> String.trim()

      is_binary(source.url) ->
        case Regex.run(~r/youtube\.com\/@([^\/?\s]+)/, source.url) do
          [_match, handle] -> handle
          _ -> nil
        end

      true ->
        nil
    end
  end

  defp fetch_feed(source, locator) do
    if is_binary(source.metadata["feed_xml"]) do
      {:ok, source.metadata["feed_xml"]}
    else
      url = feed_url(locator)

      case request(url) do
        {:ok, %{status: status, body: body}} when status in 200..299 and is_binary(body) ->
          reject_empty_feed(body, locator)

        {:ok, %{status: status}} ->
          {:error, {:feed_http_status, status, url}}

        {:error, reason} ->
          {:error,
           {:feed_request_failed, %{url: url, proxy: proxy_label(), reason: inspect(reason)}}}
      end
    end
  end

  defp reject_empty_feed(body, locator) do
    case parse_feed(body) do
      {:ok, []} -> {:error, {:feed_empty, locator}}
      {:ok, _videos} -> {:ok, body}
    end
  end

  defp parse_entry(body) do
    with {:ok, video_id} <- extract(body, ~r/<yt:videoId>(.*?)<\/yt:videoId>/s),
         {:ok, title} <- extract(body, ~r/<title>(.*?)<\/title>/s) do
      %{
        external_id: video_id,
        title: decode_xml(title),
        url: "https://www.youtube.com/watch?v=#{video_id}",
        published_at:
          body |> extract_optional(~r/<published>(.*?)<\/published>/s) |> parse_datetime(),
        updated_at: body |> extract_optional(~r/<updated>(.*?)<\/updated>/s) |> parse_datetime(),
        author: body |> extract_optional(~r/<name>(.*?)<\/name>/s) |> decode_xml(),
        discovery: "youtube_atom_feed"
      }
    else
      _ -> nil
    end
  end

  defp parse_yt_dlp_lines(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.flat_map(fn line ->
      case Jason.decode(line) do
        {:ok, data} -> yt_dlp_video(data)
        {:error, _reason} -> []
      end
    end)
  end

  defp yt_dlp_video(%{"id" => video_id} = data) when is_binary(video_id) do
    [
      %{
        external_id: video_id,
        title: data["title"],
        url: "https://www.youtube.com/watch?v=#{video_id}",
        published_at: parse_upload_date(data["upload_date"]),
        updated_at: nil,
        author: data["channel"] || data["uploader"],
        discovery: "youtube_yt_dlp_archive"
      }
    ]
  end

  defp yt_dlp_video(_data), do: []

  defp extract(body, pattern) do
    case Regex.run(pattern, body) do
      [_match, value] -> {:ok, String.trim(value)}
      _ -> {:error, :missing_value}
    end
  end

  defp extract_optional(body, pattern) do
    case Regex.run(pattern, body) do
      [_match, value] -> String.trim(value)
      _ -> nil
    end
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end

  defp parse_upload_date(<<year::binary-size(4), month::binary-size(2), day::binary-size(2)>>) do
    with {year, ""} <- Integer.parse(year),
         {month, ""} <- Integer.parse(month),
         {day, ""} <- Integer.parse(day),
         {:ok, date} <- Date.new(year, month, day),
         {:ok, datetime} <- DateTime.new(date, ~T[00:00:00], "Etc/UTC") do
      datetime
    else
      _ -> nil
    end
  end

  defp parse_upload_date(_value), do: nil

  defp decode_xml(nil), do: nil

  defp decode_xml(value) do
    value
    |> String.replace("&amp;", "&")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
  end

  defp request(url) do
    options = request_options(url)

    :get
    |> Finch.build(url, Keyword.fetch!(options, :headers))
    |> Finch.request(StreamGenome.Finch,
      receive_timeout: @receive_timeout,
      request_timeout: @receive_timeout + 5_000
    )
  end

  def request_options(url) do
    [
      url: url,
      headers: [{"user-agent", user_agent()}],
      receive_timeout: @receive_timeout,
      request_timeout: @receive_timeout + 5_000
    ]
    |> maybe_put_proxy()
  end

  defp maybe_put_proxy(options) do
    case crawler_proxy() do
      nil ->
        options

      false ->
        options

      proxy ->
        Keyword.put(options, :proxy, proxy_tuple(proxy))
    end
  end

  defp crawler_proxy do
    Crawler.youtube_crawler_options() |> Keyword.get(:proxy)
  end

  defp discovery_adapter(source) do
    cond do
      is_binary(source.metadata["feed_xml"]) ->
        :atom_feed

      true ->
        Application.get_env(:stream_genome, :youtube_crawler, [])
        |> Keyword.merge(Crawler.youtube_crawler_options())
        |> Keyword.get(:discovery_adapter, :atom_feed)
    end
  end

  defp archive_limit do
    Application.get_env(:stream_genome, :youtube_crawler, [])
    |> Keyword.merge(Crawler.youtube_crawler_options())
    |> Keyword.get(:archive_limit, 100)
  end

  defp yt_dlp_path do
    Application.get_env(:stream_genome, :youtube_crawler, [])
    |> Keyword.merge(Crawler.youtube_crawler_options())
    |> Keyword.get(:yt_dlp_path, "yt-dlp")
  end

  defp proxy_args do
    case proxy_label() do
      "direct" -> []
      proxy -> ["--proxy", proxy]
    end
  end

  defp cookies_args do
    case Application.get_env(:stream_genome, :youtube_crawler, [])
         |> Keyword.merge(Crawler.youtube_crawler_options())
         |> Keyword.get(:yt_dlp_cookies_path, "") do
      path when path in [nil, ""] -> []
      path -> if File.regular?(path), do: ["--cookies", path], else: []
    end
  end

  defp js_runtime_args do
    case Application.get_env(:stream_genome, :youtube_crawler, [])
         |> Keyword.merge(Crawler.youtube_crawler_options())
         |> Keyword.get(:yt_dlp_js_runtime, "node") do
      runtime when runtime in [nil, "", "disabled"] -> []
      runtime -> ["--no-js-runtimes", "--js-runtimes", runtime]
    end
  end

  defp archive_url(source) do
    source.url
    |> case do
      url when is_binary(url) and url != "" -> url
      _url -> "https://www.youtube.com/#{source.external_id}"
    end
    |> String.trim_trailing("/")
    |> then(fn url ->
      if String.ends_with?(url, "/videos"), do: url, else: "#{url}/videos"
    end)
  end

  defp proxy_tuple(proxy) do
    scheme = Keyword.get(proxy, :scheme, :http)
    host = Keyword.fetch!(proxy, :host)
    port = Keyword.fetch!(proxy, :port)

    {scheme, host, port, []}
  end

  defp feed_url({:channel_id, channel_id}), do: "#{@feed_base}?channel_id=#{channel_id}"
  defp feed_url({:user, user, _opts}), do: "#{@feed_base}?user=#{URI.encode(user)}"

  defp locator_channel_id({:channel_id, channel_id}), do: channel_id
  defp locator_channel_id({:user, _user, _opts}), do: nil

  defp user_agent do
    "Stream.Genome crawler prototype (+https://stream.genome.local)"
  end
end
