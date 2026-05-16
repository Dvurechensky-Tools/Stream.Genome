<p align="center">
  <img src="media/icon.ico" width="96" height="96" alt="Stream Genome icon">
</p>

<h1 align="center">Stream Genome</h1>

<p align="center">
  Open-source creator-universe engine for searchable meme, lore, callback, and narrative memory.
</p>

[Русская версия](README.ru.md)

Stream Genome is an open-source creator-universe engine. The repository name is `Stream.Genome`, but the public product name is written as **Stream Genome**.

It is not a chatbot. It is a persistent narrative intelligence system that ingests creator content, extracts transcripts, detects recurring people, memes, phrases, conflicts, callbacks, arcs, and evidence fragments, then projects them into a searchable public lore atlas.

## What It Gives Users

The public portal is meant to answer questions like:

- When did a meme or phrase first appear?
- Why does a joke keep returning across videos?
- Which people, games, conflicts, or arcs are connected?
- What exact transcript fragments support the conclusion?
- How has a creator universe changed over months or years?

For large creator archives, the goal is to turn thousands of videos into browsable cultural memory.

## Current Capabilities

- Register real YouTube channels as admin-only sources.
- Discover full channel video archives through `yt-dlp`.
- Fetch Russian/English subtitles and store transcript segments.
- Queue controlled background transcript batches.
- Queue controlled OpenAI-compatible AI extraction windows.
- Track estimated AI spend from provider token usage.
- Project AI JSON into persistent lore tables:
  - `narrative_entities`
  - `entity_aliases`
  - `entity_observations`
  - `narrative_events`
- Expose a public bilingual portal with search, source coverage, active memes, events, relationships, and evidence fragments.

## Stack

- Elixir, Phoenix
- PostgreSQL
- Oban
- Docker Compose
- `yt-dlp`
- OpenAI-compatible APIs or Ollama
- Memgraph-ready graph infrastructure

## Local Docker Setup

Start the stack:

```bash
docker compose up --build
```

Open:

```text
http://localhost:4000
http://localhost:4000/admin
http://localhost:5050
```

Default pgAdmin credentials:

```text
admin@stream.genome
admin
```

## YouTube Proxy

For a local v2rayN mixed proxy on port `10808`, Docker uses:

```text
YOUTUBE_PROXY_HOST=host.docker.internal
YOUTUBE_PROXY_PORT=10808
```

Inside Docker, `127.0.0.1` means the app container itself, so do not use `127.0.0.1:10808` for the compose app.

## YouTube Cookies

Age-restricted videos require exported browser cookies. Put a Netscape-format file here:

```text
data/youtube/cookies.txt
```

The compose app mounts `./data/youtube` into the container as `/data/youtube`.

## AI Provider

Copy `.env.example` to `.env` and configure:

```bash
AI_PROVIDER=openai
AI_ENDPOINT=https://api.openai.com/v1/chat/completions
AI_MODEL=gpt-4o-mini
AI_TEMPERATURE=0.2
AI_TIMEOUT_MS=120000
AI_INPUT_USD_PER_1M=0.15
AI_OUTPUT_USD_PER_1M=0.60
OPENAI_API_KEY=sk-...
```

The prices are configurable because model pricing changes over time.

## Admin Workflow

1. Register a YouTube channel in Admin Console.
2. Start Scan to discover videos.
3. Start transcript auto batches.
4. Start AI auto batches.
5. Watch AI Spend Timeline.
6. Inspect projected lore results.
7. Review the public portal.

## VPS Transfer

See:

- [Docker image TAR transfer](docs/docker-image-tar-vps.md)
- [VPS transfer with database dump](docs/vps-transfer.ru.md)

In short, Docker images do not contain Postgres data. Export and restore the database dump:

```bash
docker compose exec -T postgres pg_dump -U postgres --clean --if-exists --no-owner --no-privileges stream_genome_dev > data/stream_genome_vps.sql
```

## Development

Install dependencies:

```bash
mix deps.get
```

Run tests and checks:

```bash
mix precommit
```

On Windows PowerShell with script execution disabled, use `mix.bat` instead of `mix`.

## Documentation

- [Technical specification](docs/technical-specification.md)
- [Architecture](docs/architecture.md)
- [Roadmap](docs/roadmap.md)
- [Docker image TAR transfer](docs/docker-image-tar-vps.md)
- [Russian quickstart](docs/quickstart.ru.md)
