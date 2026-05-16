FROM elixir:1.18-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    ffmpeg \
    git \
    nodejs \
    npm \
    python3 \
    python3-pip \
    python3-venv \
  && python3 -m pip install --break-system-packages --no-cache-dir yt-dlp \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

ENV MIX_HOME=/root/.mix \
  HEX_HOME=/root/.hex \
  MIX_ENV=dev \
  PHX_BIND=0.0.0.0 \
  POSTGRES_HOST=postgres \
  YT_DLP_PATH=yt-dlp

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get

COPY assets assets
COPY priv priv
COPY lib lib

RUN mix assets.setup && mix assets.build

CMD ["sh", "-c", "mix ecto.create && mix ecto.migrate && mix phx.server"]
