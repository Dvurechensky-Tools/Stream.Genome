defmodule StreamGenomeWeb.AdminHTML do
  use StreamGenomeWeb, :html

  embed_templates "admin_html/*"

  def admin_source_status(%{scan_runs: [scan_run | _]}), do: scan_run.status
  def admin_source_status(_source), do: "not scanned"
end
