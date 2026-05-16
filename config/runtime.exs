import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/stream_genome start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :stream_genome, StreamGenomeWeb.Endpoint, server: true
end

config :stream_genome, StreamGenomeWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

ai_provider =
  case System.get_env("AI_PROVIDER", "disabled") do
    "openai" -> :openai_compatible
    "openai_compatible" -> :openai_compatible
    "ollama" -> :ollama
    _other -> :disabled
  end

config :stream_genome, :ai,
  provider: ai_provider,
  endpoint:
    System.get_env(
      "AI_ENDPOINT",
      if(ai_provider == :ollama,
        do: "http://ollama:11434/api/generate",
        else: "https://api.openai.com/v1/chat/completions"
      )
    ),
  model:
    System.get_env("AI_MODEL", if(ai_provider == :ollama, do: "llama3.1", else: "gpt-4o-mini")),
  api_key: System.get_env("OPENAI_API_KEY") || System.get_env("AI_API_KEY"),
  temperature: System.get_env("AI_TEMPERATURE", "0.2") |> String.to_float(),
  timeout_ms: System.get_env("AI_TIMEOUT_MS", "120000") |> String.to_integer(),
  input_usd_per_1m: System.get_env("AI_INPUT_USD_PER_1M", "0.15") |> String.to_float(),
  output_usd_per_1m: System.get_env("AI_OUTPUT_USD_PER_1M", "0.60") |> String.to_float()

if youtube_proxy_url = System.get_env("YOUTUBE_PROXY_URL") do
  proxy_uri = URI.parse(youtube_proxy_url)

  discovery_adapter =
    case System.get_env("YOUTUBE_DISCOVERY_ADAPTER", "yt_dlp") do
      "yt_dlp" -> :yt_dlp
      _other -> :atom_feed
    end

  proxy_scheme =
    case proxy_uri.scheme do
      "https" -> :https
      _other -> :http
    end

  config :stream_genome, :youtube_crawler,
    discovery_adapter: discovery_adapter,
    archive_limit: String.to_integer(System.get_env("YOUTUBE_ARCHIVE_LIMIT", "7500")),
    yt_dlp_path: System.get_env("YT_DLP_PATH", "yt-dlp"),
    yt_dlp_cookies_path: System.get_env("YT_DLP_COOKIES_PATH", "/data/youtube/cookies.txt"),
    proxy: [
      scheme: proxy_scheme,
      host: proxy_uri.host,
      port: proxy_uri.port
    ]
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :stream_genome, StreamGenome.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("DB_POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :stream_genome, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :stream_genome, StreamGenomeWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :stream_genome, StreamGenomeWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :stream_genome, StreamGenomeWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :stream_genome, StreamGenome.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
