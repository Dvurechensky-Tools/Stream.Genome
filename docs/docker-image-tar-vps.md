# Docker Image TAR Transfer to a VPS

[Русская версия](docker-image-tar-vps.ru.md)

This guide is for a future deployment path where the app image is built locally, saved as a `.tar` archive, copied to a VPS, and started there with Docker Compose.

It is useful when you do not want to publish the image to Docker Hub or any private registry yet.

## What Goes Into the Archive

The Docker image contains:

- Elixir/Phoenix runtime dependencies
- application code copied by the `Dockerfile`
- built frontend assets
- `yt-dlp`, Node.js, Python, and ffmpeg tools installed inside the image

The image does not contain:

- PostgreSQL data
- Memgraph data
- `.env`
- OpenAI API keys
- YouTube cookies
- local `data/` dumps

Those must stay outside the image.

## Files That Must Not Be Published

Before open-source publication or transfer, keep these local only:

```text
.env
CREDENTIALS.md
data/
data/youtube/cookies.txt
data/stream_genome_vps.sql
*.tar
*.sql
```

They are ignored by `.gitignore` and `.dockerignore`.

## 1. Build a Local Image

From the repository root:

```bash
docker build -t stream-genome-app:local .
```

This creates a portable app image named `stream-genome-app:local`.

## 2. Save the Image to TAR

```bash
mkdir -p data/releases
docker save stream-genome-app:local -o data/releases/stream-genome-app.local.tar
```

The archive is intentionally written under `data/`, so it stays ignored by git.

## 3. Optional: Export the Current Database

Docker images do not include database volumes. If you want the VPS to start with the already collected data:

```bash
docker compose exec -T postgres pg_dump -U postgres --clean --if-exists --no-owner --no-privileges stream_genome_dev > data/stream_genome_vps.sql
```

## 4. Copy Files to the VPS

Copy these files/directories:

```text
data/releases/stream-genome-app.local.tar
docker-compose.yml
.env
data/stream_genome_vps.sql          # optional database dump
data/youtube/cookies.txt            # optional, only for age-restricted YouTube videos
docker/pgadmin/servers.json
```

You can use `scp`, SFTP, rsync, or your VPS provider file manager.

## 5. Load the Image on the VPS

On the VPS:

```bash
docker load -i data/releases/stream-genome-app.local.tar
```

Check that the image exists:

```bash
docker images stream-genome-app
```

## 6. Use the Loaded Image in Compose

For an image-only VPS run, change the `app` service in `docker-compose.yml`:

```yaml
services:
  app:
    image: stream-genome-app:local
    # remove the build block on the VPS
```

For the current development compose file, also remove the source-code bind mount on the VPS:

```yaml
    volumes:
      - ./data/youtube:/data/youtube
```

Keep named volumes for Postgres, Memgraph, pgAdmin, deps/build only if you continue using the development workflow.

## 7. Restore the Database Dump

Start Postgres first:

```bash
docker compose up -d postgres
```

Restore:

```bash
docker compose exec -T postgres psql -U postgres -d stream_genome_dev < data/stream_genome_vps.sql
```

Then start everything:

```bash
docker compose up -d
```

## 8. Configure Runtime Secrets

Create `.env` on the VPS from `.env.example`:

```bash
cp .env.example .env
```

Set at least:

```text
AI_PROVIDER=openai
AI_ENDPOINT=https://api.openai.com/v1/chat/completions
AI_MODEL=gpt-4o-mini
OPENAI_API_KEY=...
YT_DLP_COOKIES_PATH=/data/youtube/cookies.txt
```

Never commit `.env` or cookies.

## 9. Basic Smoke Test

Open:

```text
http://YOUR_VPS_IP:4000
http://YOUR_VPS_IP:4000/admin
```

Then verify:

- public portal loads
- admin console loads
- sources are visible if the database dump was restored
- transcript and AI workers can queue jobs
- AI Spend Timeline records token usage after model runs

## Production Note

The current compose setup is intentionally practical and development-friendly. Before serious public traffic, add:

- HTTPS reverse proxy
- real admin authentication
- restricted pgAdmin access or remove pgAdmin from public VPS
- database backups
- log rotation
- worker rate limits
- monitoring for AI spend and YouTube failures
