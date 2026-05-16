<p align="center">
  <img src="media/icon.ico" width="96" height="96" alt="Иконка Генома Стрима">
</p>

<h1 align="center">Геном Стрима</h1>

<p align="center">
  Open-source движок вселенных авторов: поиск по мемам, лору, колбэкам и нарративной памяти.
</p>

[English version](README.md)

**Геном Стрима** — публичное название open-source проекта `Stream.Genome`.

Это не чат-бот. Это движок постоянного нарративного интеллекта: он собирает контент авторов, достаёт транскрипты, находит повторяющихся людей, мемы, фразы, конфликты, колбэки, арки и доказательные фрагменты, а затем превращает всё это в поисковый публичный атлас лора.

## Что это даёт людям

Портал должен отвечать на вопросы:

- Когда появился мем или фраза?
- Почему шутка возвращается в разных видео?
- Какие люди, игры, конфликты и арки связаны?
- На каких конкретных фрагментах основан вывод?
- Как вселенная автора менялась месяцами и годами?

Идея в том, чтобы превратить тысячи видео в просматриваемую культурную память.

## Что уже умеет

- Добавлять реальные YouTube-каналы через админку.
- Собирать полный архив видео через `yt-dlp`.
- Получать русские/английские субтитры и хранить строки транскриптов.
- Запускать контролируемые фоновые батчи транскриптов.
- Запускать контролируемые AI-батчи через OpenAI-compatible API.
- Считать примерную стоимость OpenAI по token usage.
- Проецировать AI JSON в постоянные таблицы лора:
  - `narrative_entities`
  - `entity_aliases`
  - `entity_observations`
  - `narrative_events`
- Показывать публичный двуязычный портал с поиском, источниками, мемами, событиями, связями и доказательными фрагментами.

## Стек

- Elixir, Phoenix
- PostgreSQL
- Oban
- Docker Compose
- `yt-dlp`
- OpenAI-compatible API или Ollama
- инфраструктура под Memgraph

## Локальный запуск через Docker

```bash
docker compose up --build
```

Открыть:

```text
http://localhost:4000
http://localhost:4000/admin
http://localhost:5050
```

Данные pgAdmin по умолчанию:

```text
admin@stream.genome
admin
```

## Прокси YouTube

Для локального v2rayN mixed proxy на порту `10808` Docker использует:

```text
YOUTUBE_PROXY_HOST=host.docker.internal
YOUTUBE_PROXY_PORT=10808
```

Внутри Docker `127.0.0.1` означает сам контейнер приложения, поэтому для compose-приложения не нужно ставить `127.0.0.1:10808`.

## Cookies YouTube

Видео с age restriction требуют cookies из браузера. Файл в Netscape-формате кладётся сюда:

```text
data/youtube/cookies.txt
```

Папка `./data/youtube` монтируется в контейнер как `/data/youtube`.

## AI Provider

Скопируй `.env.example` в `.env` и настрой:

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

Цены вынесены в настройки, потому что прайс моделей может меняться.

## Рабочий процесс в админке

1. Добавить YouTube-канал.
2. Запустить Scan для сбора видео.
3. Запустить авто-батчи транскриптов.
4. Запустить авто-батчи AI-анализа.
5. Смотреть AI Spend Timeline.
6. Проверять Projected Lore Result.
7. Смотреть публичный портал.

## Перенос на VPS

См.:

- [перенос Docker image через TAR-архив](docs/docker-image-tar-vps.ru.md)
- [перенос на VPS с дампом базы](docs/vps-transfer.ru.md)

Коротко: Docker image не содержит данные Postgres. Нужно отдельно экспортировать и восстановить дамп:

```bash
docker compose exec -T postgres pg_dump -U postgres --clean --if-exists --no-owner --no-privileges stream_genome_dev > data/stream_genome_vps.sql
```

## Разработка

```bash
mix deps.get
mix precommit
```

На Windows PowerShell с отключённым запуском скриптов используй `mix.bat` вместо `mix`.

## Документация

- [Техническая спецификация](docs/technical-specification.ru.md)
- [Roadmap](docs/roadmap.ru.md)
- [Quickstart](docs/quickstart.ru.md)
- [Перенос Docker image через TAR-архив](docs/docker-image-tar-vps.ru.md)
