defmodule StreamGenome.Crawler do
  @moduledoc """
  Runtime crawler configuration and operational controls.
  """

  alias StreamGenome.Crawler.Setting
  alias StreamGenome.Repo

  @network_key "network"

  def get_network_settings do
    defaults = default_network_settings()

    case Repo.get_by(Setting, key: @network_key) do
      %Setting{value: value} -> Map.merge(defaults, value || %{})
      nil -> defaults
    end
  end

  def update_network_settings(attrs) do
    value = %{
      "proxy_enabled" => truthy?(attrs["proxy_enabled"]),
      "proxy_scheme" => normalize_scheme(attrs["proxy_scheme"]),
      "proxy_host" => attrs["proxy_host"] |> to_string() |> String.trim(),
      "proxy_port" => parse_port(attrs["proxy_port"]),
      "archive_limit" => parse_limit(attrs["archive_limit"]),
      "transcript_languages" => normalize_languages(attrs["transcript_languages"]),
      "yt_dlp_js_runtime" => normalize_js_runtime(attrs["yt_dlp_js_runtime"]),
      "yt_dlp_cookies_path" => normalize_path(attrs["yt_dlp_cookies_path"]),
      "discovery_adapter" => normalize_adapter(attrs["discovery_adapter"])
    }

    setting = Repo.get_by(Setting, key: @network_key) || %Setting{key: @network_key}

    setting
    |> Setting.changeset(%{key: @network_key, value: value})
    |> Repo.insert_or_update()
  end

  def youtube_crawler_options do
    settings = get_network_settings()

    [
      discovery_adapter: adapter_atom(settings["discovery_adapter"]),
      archive_limit: settings["archive_limit"],
      transcript_languages: settings["transcript_languages"],
      yt_dlp_js_runtime: settings["yt_dlp_js_runtime"],
      yt_dlp_cookies_path: settings["yt_dlp_cookies_path"],
      yt_dlp_path: System.get_env("YT_DLP_PATH", "yt-dlp")
    ]
    |> maybe_put_proxy(settings)
  rescue
    _error ->
      Application.get_env(:stream_genome, :youtube_crawler, [])
  end

  def proxy_label do
    settings = get_network_settings()

    if settings["proxy_enabled"] do
      "#{settings["proxy_scheme"]}://#{settings["proxy_host"]}:#{settings["proxy_port"]}"
    else
      "direct"
    end
  rescue
    _error ->
      fallback_proxy_label()
  end

  def cookies_label do
    case get_network_settings()["yt_dlp_cookies_path"] do
      path when is_binary(path) and path != "" -> path
      _other -> "not configured"
    end
  rescue
    _error -> System.get_env("YT_DLP_COOKIES_PATH", "") |> blank_label()
  end

  def cookies_status do
    path =
      case get_network_settings()["yt_dlp_cookies_path"] do
        value when is_binary(value) and value != "" -> value
        _other -> "/data/youtube/cookies.txt"
      end

    case File.stat(path) do
      {:ok, stat} ->
        %{
          path: path,
          exists?: true,
          size: stat.size,
          updated_at: stat.mtime
        }

      {:error, _reason} ->
        %{
          path: path,
          exists?: false,
          size: 0,
          updated_at: nil
        }
    end
  rescue
    _error -> %{path: "/data/youtube/cookies.txt", exists?: false, size: 0, updated_at: nil}
  end

  def save_youtube_cookies(attrs) do
    path =
      attrs
      |> Map.get("path", "/data/youtube/cookies.txt")
      |> normalize_path()

    content =
      attrs
      |> Map.get("content", "")
      |> to_string()
      |> String.trim()

    if content == "" do
      {:error, :empty_cookies}
    else
      path
      |> Path.dirname()
      |> File.mkdir_p!()

      File.write(path, content <> "\n")

      settings =
        get_network_settings()
        |> Map.put("yt_dlp_cookies_path", path)

      update_network_settings(settings)
    end
  rescue
    error -> {:error, error}
  end

  defp maybe_put_proxy(options, %{"proxy_enabled" => true} = settings) do
    Keyword.put(options, :proxy,
      scheme: scheme_atom(settings["proxy_scheme"]),
      host: settings["proxy_host"],
      port: settings["proxy_port"]
    )
  end

  defp maybe_put_proxy(options, _settings), do: options

  defp default_network_settings do
    configured = Application.get_env(:stream_genome, :youtube_crawler, [])
    proxy = Keyword.get(configured, :proxy)

    %{
      "proxy_enabled" => is_list(proxy),
      "proxy_scheme" => proxy |> proxy_value(:scheme, :http) |> Atom.to_string(),
      "proxy_host" =>
        proxy_value(proxy, :host, System.get_env("YOUTUBE_PROXY_HOST", "127.0.0.1")),
      "proxy_port" =>
        proxy_value(
          proxy,
          :port,
          String.to_integer(System.get_env("YOUTUBE_PROXY_PORT", "10808"))
        ),
      "archive_limit" => Keyword.get(configured, :archive_limit, 7_500),
      "transcript_languages" => Keyword.get(configured, :transcript_languages, "ru-orig,ru"),
      "yt_dlp_js_runtime" => Keyword.get(configured, :yt_dlp_js_runtime, "node"),
      "yt_dlp_cookies_path" =>
        Keyword.get(
          configured,
          :yt_dlp_cookies_path,
          System.get_env("YT_DLP_COOKIES_PATH", "/data/youtube/cookies.txt")
        ),
      "discovery_adapter" =>
        configured |> Keyword.get(:discovery_adapter, :yt_dlp) |> Atom.to_string()
    }
  end

  defp proxy_value(proxy, key, default) when is_list(proxy), do: Keyword.get(proxy, key, default)
  defp proxy_value(_proxy, _key, default), do: default

  defp truthy?(value), do: value in [true, "true", "1", "on", "yes"]

  defp normalize_scheme("https"), do: "https"
  defp normalize_scheme(_value), do: "http"

  defp normalize_adapter("atom_feed"), do: "atom_feed"
  defp normalize_adapter(_value), do: "yt_dlp"

  defp normalize_languages(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> "ru-orig,ru"
      languages -> languages
    end
  end

  defp normalize_js_runtime(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> "node"
      "disabled" -> "disabled"
      runtime -> runtime
    end
  end

  defp normalize_path(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> System.get_env("YT_DLP_COOKIES_PATH", "/data/youtube/cookies.txt")
      path -> path
    end
  end

  defp parse_port(value) do
    value
    |> to_string()
    |> Integer.parse()
    |> case do
      {port, ""} when port > 0 and port < 65_536 -> port
      _other -> 10808
    end
  end

  defp parse_limit(value) do
    value
    |> to_string()
    |> Integer.parse()
    |> case do
      {limit, ""} when limit > 0 -> limit
      _other -> 7_500
    end
  end

  defp adapter_atom("atom_feed"), do: :atom_feed
  defp adapter_atom(_value), do: :yt_dlp

  defp scheme_atom("https"), do: :https
  defp scheme_atom(_value), do: :http

  defp fallback_proxy_label do
    case Application.get_env(:stream_genome, :youtube_crawler, []) |> Keyword.get(:proxy) do
      proxy when is_list(proxy) ->
        scheme = proxy |> Keyword.get(:scheme, :http) |> Atom.to_string()
        "#{scheme}://#{Keyword.get(proxy, :host)}:#{Keyword.get(proxy, :port)}"

      _other ->
        "direct"
    end
  end

  defp blank_label(""), do: "not configured"
  defp blank_label(value), do: value
end
