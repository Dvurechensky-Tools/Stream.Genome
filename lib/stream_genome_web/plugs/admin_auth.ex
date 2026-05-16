defmodule StreamGenomeWeb.Plugs.AdminAuth do
  @moduledoc """
  Protects operational ingestion and scanning tools.

  Development and test remain open by default. Production requires
  STREAM_GENOME_ADMIN_USER and STREAM_GENOME_ADMIN_PASSWORD.
  """

  import Plug.Conn
  import Phoenix.Controller

  @open_admin? Application.compile_env(:stream_genome, :open_admin?, false)

  def init(opts), do: opts

  def call(conn, _opts) do
    if @open_admin? do
      conn
    else
      authenticate(conn)
    end
  end

  defp authenticate(conn) do
    username = System.get_env("STREAM_GENOME_ADMIN_USER")
    password = System.get_env("STREAM_GENOME_ADMIN_PASSWORD")

    if username && password do
      Plug.BasicAuth.basic_auth(conn, username: username, password: password)
    else
      conn
      |> put_status(:service_unavailable)
      |> text("Admin credentials are not configured.")
      |> halt()
    end
  end
end
