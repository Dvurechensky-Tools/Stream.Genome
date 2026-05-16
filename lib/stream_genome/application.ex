defmodule StreamGenome.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      StreamGenomeWeb.Telemetry,
      StreamGenome.Repo,
      {Oban, Application.fetch_env!(:stream_genome, Oban)},
      {DNSCluster, query: Application.get_env(:stream_genome, :dns_cluster_query) || :ignore},
      {Finch, finch_options()},
      {Phoenix.PubSub, name: StreamGenome.PubSub},
      # Start a worker by calling: StreamGenome.Worker.start_link(arg)
      # {StreamGenome.Worker, arg},
      # Start to serve requests, typically the last entry
      StreamGenomeWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: StreamGenome.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    StreamGenomeWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp finch_options do
    [name: StreamGenome.Finch]
    |> Keyword.merge(finch_proxy_pool_options())
  end

  defp finch_proxy_pool_options do
    case Application.get_env(:stream_genome, :youtube_crawler, []) |> Keyword.get(:proxy) do
      nil ->
        []

      false ->
        []

      proxy ->
        [
          pools: %{
            default: [
              conn_opts: [
                proxy: proxy_tuple(proxy),
                protocols: [:http1]
              ]
            ]
          }
        ]
    end
  end

  defp proxy_tuple(proxy) do
    scheme = Keyword.get(proxy, :scheme, :http)
    host = Keyword.fetch!(proxy, :host)
    port = Keyword.fetch!(proxy, :port)

    {scheme, host, port, []}
  end
end
