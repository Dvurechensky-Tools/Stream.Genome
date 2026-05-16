defmodule StreamGenomeWeb.AdminSourceHTML do
  use StreamGenomeWeb, :html

  alias StreamGenome.YouTube.VideoDiscovery

  embed_templates "admin_source_html/*"

  def latest_scan_run(%{scan_runs: [scan_run | _]}), do: scan_run
  def latest_scan_run(_source), do: nil

  def latest_status(%{scan_runs: [scan_run | _]}), do: scan_run.status
  def latest_status(_source), do: "not scanned"

  def auto_refresh?(%{scan_runs: [%{status: status} | _]}) when status in ["queued", "running"],
    do: true

  def auto_refresh?(_source), do: false

  def transcript_refresh?(%{queued: queued, running: running}), do: queued + running > 0
  def transcript_refresh?(_snapshot), do: false

  def intelligence_refresh?(%{runs_queued: queued, runs_awaiting_model: awaiting}),
    do: queued + awaiting > 0

  def intelligence_refresh?(_snapshot), do: false

  def transcript_percent(%{total: total}) when total in [nil, 0], do: 0

  def transcript_percent(%{total: total, completed: completed}) do
    floor(completed * 100 / total)
  end

  def intelligence_percent(%{total_segments: total}) when total in [nil, 0], do: 0

  def intelligence_percent(%{total_segments: total, extracted_segments: extracted}) do
    floor(extracted * 100 / total)
  end

  def proxy_label, do: VideoDiscovery.proxy_label()
  def cookies_label, do: StreamGenome.Crawler.cookies_label()

  def language_label(nil), do: "unknown"
  def language_label(""), do: "unknown"
  def language_label(language), do: language

  def extraction_status_class("completed"), do: "bg-success/15 text-success"
  def extraction_status_class("failed"), do: "bg-error/15 text-error"

  def extraction_status_class(status) when status in ["queued", "awaiting_model"],
    do: "bg-info/15 text-info"

  def extraction_status_class(_status), do: "bg-base-200 text-base-content/70"

  def metadata_value(nil, _key), do: "not recorded"

  def metadata_value(%{metadata: metadata}, key) when is_map(metadata) do
    metadata
    |> Map.get(key)
    |> case do
      nil -> "not recorded"
      value when is_binary(value) -> value
      value -> inspect(value)
    end
  end

  def status_class("completed"), do: "bg-success/15 text-success"
  def status_class("failed"), do: "bg-error/15 text-error"
  def status_class(status) when status in ["queued", "running"], do: "bg-info/15 text-info"
  def status_class(_status), do: "bg-base-200 text-base-content/70"

  def primary_diagnostic(scan_run) do
    case metadata_value(scan_run, "failure_reason") do
      "not recorded" -> metadata_value(scan_run, "feed_locator")
      reason -> reason
    end
  end

  def full_error(nil), do: "no error recorded"
  def full_error(value) when is_binary(value), do: value
  def full_error(value), do: inspect(value, limit: :infinity, printable_limit: :infinity)

  def run_result_preview(%{result: result}) when result in [nil, %{}], do: nil

  def run_result_preview(%{result: result}) do
    result
    |> Jason.encode!()
    |> String.slice(0, 1_500)
  end

  def percent_label(nil), do: "0%"
  def percent_label(value) when is_float(value), do: "#{round(value * 100)}%"
  def percent_label(value) when is_integer(value), do: "#{value * 100}%"
  def percent_label(_value), do: "0%"

  def money(value) when is_float(value), do: "$#{:erlang.float_to_binary(value, decimals: 4)}"
  def money(value) when is_integer(value), do: "$#{value}.0000"
  def money(_value), do: "$0.0000"

  def integer(value) when is_integer(value), do: Integer.to_string(value)
  def integer(value) when is_float(value), do: value |> round() |> Integer.to_string()
  def integer(_value), do: "0"

  def format_datetime(nil), do: "not yet"

  def format_datetime(%DateTime{} = value) do
    Calendar.strftime(value, "%Y-%m-%d %H:%M UTC")
  end

  def format_datetime(%NaiveDateTime{} = value) do
    value
    |> DateTime.from_naive!("Etc/UTC")
    |> format_datetime()
  end
end
