# Перенос Stream.Genome на VPS с уже собранными данными

Docker-образ приложения не содержит данные Postgres. Видео, транскрипты, AI-runs и лор-граф лежат в volume базы. Для VPS нужно переносить код/compose и дамп базы.

## 1. Убрать демо-данные локально

```powershell
docker compose exec -T app mix stream_genome.clean_demo
```

Команда удаляет только demo-источник `Northstar Streams`, `Chair Arc` и записи с `metadata.demo=true`. Реальный YouTube-канал и уже загруженные данные не трогает.

## 2. Сделать дамп Postgres

```powershell
New-Item -ItemType Directory -Force data
docker compose exec -T postgres pg_dump -U postgres --clean --if-exists --no-owner --no-privileges stream_genome_dev > data/stream_genome_vps.sql
```

## 3. Скопировать на VPS

Скопируй репозиторий и файл:

```text
data/stream_genome_vps.sql
```

Если используешь YouTube cookies для age-restricted видео, отдельно перенеси:

```text
data/youtube/cookies.txt
```

## 4. Восстановить базу на VPS

На VPS:

```bash
docker compose up -d postgres
docker compose exec -T postgres psql -U postgres -d stream_genome_dev < data/stream_genome_vps.sql
docker compose up -d
```

После этого портал поднимется уже с сохранёнными источниками, видео, транскриптами, AI-окнами, сущностями и событиями.

## 5. Не грузить демо при seed

По умолчанию `priv/repo/seeds.exs` больше не грузит demo-lore. Если демо когда-нибудь понадобится:

```bash
LOAD_DEMO=true docker compose exec -T app mix run priv/repo/seeds.exs
```
