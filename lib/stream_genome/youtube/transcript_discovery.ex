defmodule StreamGenome.YouTube.TranscriptDiscovery do
  @moduledoc """
  Fetches YouTube subtitles/transcripts and converts VTT cues to content segments.
  """

  alias StreamGenome.Crawler
  alias StreamGenome.Narrative.ContentItem

  def fetch(%ContentItem{} = item) do
    cond do
      is_binary(item.metadata["transcript_vtt"]) ->
        language = item.metadata["transcript_language"] || item.language || "unknown"
        {:ok, item.metadata["transcript_vtt"] |> parse_vtt() |> tag_language(language)}

      is_binary(item.url) ->
        fetch_with_yt_dlp(item)

      true ->
        {:error, :missing_video_url}
    end
  end

  def parse_vtt(vtt) when is_binary(vtt) do
    vtt
    |> String.replace("\r\n", "\n")
    |> String.split(~r/\n{2,}/, trim: true)
    |> Enum.flat_map(&parse_block/1)
    |> collapse_rolling_captions()
  end

  defp fetch_with_yt_dlp(item) do
    work_dir = Path.join(System.tmp_dir!(), "stream_genome_transcripts/#{item.id}")
    File.rm_rf!(work_dir)
    File.mkdir_p!(work_dir)

    output_template = Path.join(work_dir, "#{item.external_id || item.id}.%(ext)s")

    args =
      [
        "--skip-download",
        "--write-subs",
        "--write-auto-subs",
        "--sub-langs",
        transcript_languages(),
        "--sub-format",
        "vtt",
        "--output",
        output_template
      ] ++ cookies_args() ++ js_runtime_args() ++ proxy_args() ++ [item.url]

    executable = yt_dlp_path()

    case System.cmd(executable, args, stderr_to_stdout: true) do
      {_output, 0} ->
        parse_downloaded_vtt(work_dir)

      {output, exit_status} ->
        case parse_downloaded_vtt(work_dir) do
          {:ok, segments} ->
            {:ok, segments}

          {:error, _reason} ->
            {:error,
             {:yt_dlp_transcript_failed,
              %{
                exit_status: exit_status,
                executable: executable,
                args: args,
                cookies_path: cookies_path(),
                cookies_file_exists: cookies_file_exists?(),
                output: String.trim(output)
              }}}
        end
    end
  rescue
    ErlangError ->
      {:error, {:yt_dlp_not_found, yt_dlp_path()}}
  end

  defp parse_block(block) do
    lines =
      block
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    with timestamp_line when is_binary(timestamp_line) <-
           Enum.find(lines, &String.contains?(&1, "-->")),
         {:ok, starts_at_ms, ends_at_ms} <- parse_timestamp_line(timestamp_line) do
      body =
        lines
        |> Enum.drop_while(&(&1 != timestamp_line))
        |> Enum.drop(1)
        |> Enum.map(&clean_text/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.join(" ")

      if body == "" or ends_at_ms - starts_at_ms < 500 do
        []
      else
        [%{body: body, starts_at_ms: starts_at_ms, ends_at_ms: ends_at_ms}]
      end
    else
      _other -> []
    end
  end

  defp parse_timestamp_line(line) do
    pattern =
      ~r/(?:(\d+):)?(\d{2}):(\d{2})\.(\d{3})\s+-->\s+(?:(\d+):)?(\d{2}):(\d{2})\.(\d{3})/

    case Regex.run(pattern, line) do
      [_match, start_h, start_m, start_s, start_ms, end_h, end_m, end_s, end_ms] ->
        {:ok, timestamp_to_ms(start_h, start_m, start_s, start_ms),
         timestamp_to_ms(end_h, end_m, end_s, end_ms)}

      _other ->
        {:error, :invalid_timestamp}
    end
  end

  defp timestamp_to_ms(hours, minutes, seconds, millis) do
    hours = if hours in [nil, ""], do: 0, else: String.to_integer(hours)

    (hours * 60 * 60 + String.to_integer(minutes) * 60 + String.to_integer(seconds)) * 1000 +
      String.to_integer(millis)
  end

  defp clean_text(text) do
    text
    |> String.replace(~r/<[^>]+>/, "")
    |> String.replace(~r/&amp;/, "&")
    |> String.replace(~r/&lt;/, "<")
    |> String.replace(~r/&gt;/, ">")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp pick_vtt_file(work_dir) do
    files =
      work_dir
      |> Path.join("*.vtt")
      |> Path.wildcard()
      |> Enum.sort()

    Enum.find(files, &String.contains?(&1, ".ru-orig.")) ||
      Enum.find(files, &String.contains?(&1, ".ru.")) ||
      Enum.find(files, &String.contains?(&1, ".ru")) ||
      Enum.find(files, &String.contains?(&1, ".en")) ||
      List.first(files)
  end

  defp parse_downloaded_vtt(work_dir) do
    case pick_vtt_file(work_dir) do
      nil ->
        {:error, :transcript_not_found}

      path ->
        {:ok, path |> File.read!() |> parse_vtt() |> tag_language(language_from_vtt_path(path))}
    end
  end

  defp tag_language(segments, language) do
    normalized = normalize_language(language)
    Enum.map(segments, &Map.put(&1, :language, normalized))
  end

  defp language_from_vtt_path(path) do
    filename = Path.basename(path)

    cond do
      String.contains?(filename, ".ru-orig.") -> "ru"
      String.contains?(filename, ".ru.") -> "ru"
      String.contains?(filename, ".ru-") -> "ru"
      String.contains?(filename, ".en.") -> "en"
      String.contains?(filename, ".en-") -> "en"
      true -> "unknown"
    end
  end

  defp normalize_language(nil), do: "unknown"
  defp normalize_language(""), do: "unknown"

  defp normalize_language(language) when is_binary(language) do
    language
    |> String.downcase()
    |> String.split(["-", "_"], parts: 2)
    |> List.first()
    |> case do
      nil -> "unknown"
      "" -> "unknown"
      value -> value
    end
  end

  defp collapse_rolling_captions(segments) do
    segments
    |> Enum.reduce([], fn segment, acc ->
      case acc do
        [previous | rest] ->
          previous_text = normalize_caption(previous.body)
          current_text = normalize_caption(segment.body)

          cond do
            current_text == previous_text ->
              [merge_segments(previous, segment) | rest]

            String.contains?(current_text, previous_text) and
                segment.starts_at_ms - previous.ends_at_ms <= 1_000 ->
              [segment | rest]

            true ->
              [segment, previous | rest]
          end

        [] ->
          [segment]
      end
    end)
    |> Enum.reverse()
  end

  defp merge_segments(previous, current) do
    %{
      previous
      | starts_at_ms: min(previous.starts_at_ms, current.starts_at_ms),
        ends_at_ms: max(previous.ends_at_ms, current.ends_at_ms)
    }
  end

  defp normalize_caption(text) do
    text
    |> String.downcase()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp yt_dlp_path do
    Crawler.youtube_crawler_options()
    |> Keyword.get(:yt_dlp_path, "yt-dlp")
  end

  defp transcript_languages do
    Crawler.youtube_crawler_options()
    |> Keyword.get(:transcript_languages, "ru-orig,ru")
  end

  defp js_runtime_args do
    case Crawler.youtube_crawler_options() |> Keyword.get(:yt_dlp_js_runtime, "node") do
      runtime when runtime in [nil, "", "disabled"] -> []
      runtime -> ["--no-js-runtimes", "--js-runtimes", runtime]
    end
  end

  defp cookies_args do
    case cookies_path() do
      path when path in [nil, ""] -> []
      path -> if File.regular?(path), do: ["--cookies", path], else: []
    end
  end

  defp cookies_path do
    Crawler.youtube_crawler_options() |> Keyword.get(:yt_dlp_cookies_path, "")
  end

  defp cookies_file_exists? do
    case cookies_path() do
      path when path in [nil, ""] -> false
      path -> File.regular?(path)
    end
  end

  defp proxy_args do
    case Crawler.proxy_label() do
      "direct" -> []
      proxy -> ["--proxy", proxy]
    end
  end
end
