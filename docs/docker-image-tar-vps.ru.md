# Перенос Docker image в TAR-архиве на VPS

[English version](docker-image-tar-vps.md)

Эта инструкция нужна для будущего сценария: собрать Docker image локально, сохранить его в `.tar`, перенести на VPS и запустить через Docker Compose.

Так можно не публиковать образ в Docker Hub или private registry, пока проект еще не готов к нормальному продакшен-релизу.

## Что попадает в архив

Docker image содержит:

- Elixir/Phoenix runtime-зависимости
- код приложения, который копируется через `Dockerfile`
- собранные frontend assets
- `yt-dlp`, Node.js, Python и ffmpeg внутри образа

Docker image не содержит:

- данные PostgreSQL
- данные Memgraph
- `.env`
- OpenAI API keys
- YouTube cookies
- локальные дампы из `data/`

Все это должно жить отдельно от образа.

## Что нельзя публиковать

Перед open-source публикацией и переносом держи локально:

```text
.env
CREDENTIALS.md
data/
data/youtube/cookies.txt
data/stream_genome_vps.sql
*.tar
*.sql
```

Эти файлы закрыты через `.gitignore` и `.dockerignore`.

## 1. Собрать локальный образ

Из корня репозитория:

```bash
docker build -t stream-genome-app:local .
```

Появится переносимый образ `stream-genome-app:local`.

## 2. Сохранить образ в TAR

```bash
mkdir -p data/releases
docker save stream-genome-app:local -o data/releases/stream-genome-app.local.tar
```

Архив специально кладется в `data/`, чтобы он не попал в git.

На Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force data/releases
docker save stream-genome-app:local -o data/releases/stream-genome-app.local.tar
```

## 3. Если нужны уже собранные данные, сделать дамп базы

Docker image не хранит volume базы. Если хочешь перенести уже собранные видео, транскрипты, AI runs и лор:

```powershell
docker compose exec -T postgres pg_dump -U postgres --clean --if-exists --no-owner --no-privileges stream_genome_dev > data/stream_genome_vps.sql
```

## 4. Скопировать файлы на VPS

На VPS нужно перенести:

```text
data/releases/stream-genome-app.local.tar
docker-compose.yml
.env
data/stream_genome_vps.sql          # опционально, если переносишь базу
data/youtube/cookies.txt            # опционально, для age-restricted YouTube видео
docker/pgadmin/servers.json
```

Можно использовать `scp`, SFTP, rsync или файловый менеджер провайдера VPS.

## 5. Загрузить образ на VPS

На VPS:

```bash
docker load -i data/releases/stream-genome-app.local.tar
```

Проверить:

```bash
docker images stream-genome-app
```

## 6. Подключить образ в Compose

Для VPS-запуска через готовый image в `docker-compose.yml` у сервиса `app` нужно заменить `build` на `image`:

```yaml
services:
  app:
    image: stream-genome-app:local
    # build-блок на VPS не нужен
```

Также для image-only запуска лучше убрать bind mount исходников:

```yaml
    volumes:
      - ./data/youtube:/data/youtube
```

То есть на VPS приложению нужен только runtime mount для YouTube cookies. Код уже внутри image.

## 7. Восстановить базу

Сначала поднять Postgres:

```bash
docker compose up -d postgres
```

Восстановить дамп:

```bash
docker compose exec -T postgres psql -U postgres -d stream_genome_dev < data/stream_genome_vps.sql
```

Потом поднять весь стек:

```bash
docker compose up -d
```

## 8. Настроить секреты на VPS

Создать `.env` из примера:

```bash
cp .env.example .env
```

Минимально настроить:

```text
AI_PROVIDER=openai
AI_ENDPOINT=https://api.openai.com/v1/chat/completions
AI_MODEL=gpt-4o-mini
OPENAI_API_KEY=...
YT_DLP_COOKIES_PATH=/data/youtube/cookies.txt
```

`.env` и cookies нельзя коммитить.

## 9. Быстрая проверка после запуска

Открыть:

```text
http://YOUR_VPS_IP:4000
http://YOUR_VPS_IP:4000/admin
```

Проверить:

- публичный портал открывается
- админка открывается
- источники видны, если дамп базы восстановлен
- transcript jobs ставятся в очередь
- AI jobs ставятся в очередь
- AI Spend Timeline пополняется после model runs

## Важное перед публичным трафиком

Текущий compose практичный и удобный для разработки/первого VPS. Перед настоящей публичной эксплуатацией нужны:

- HTTPS reverse proxy
- нормальная admin-аутентификация
- закрыть pgAdmin от публичного интернета или убрать его с VPS
- backup базы
- log rotation
- лимиты воркеров
- мониторинг AI spend и ошибок YouTube
