defmodule StreamGenomeWeb.PageHTML do
  @moduledoc """
  Public HTML helpers for the creator-universe portal.
  """

  use StreamGenomeWeb, :html

  embed_templates "page_html/*"

  def home_copy("en") do
    %{
      brand: "Stream Genome",
      explore: "Explore Atlas",
      sources: "Sources",
      eyebrow: "public creator lore atlas",
      headline: "Creator universes, indexed as living lore.",
      lead:
        "Search memes, phrases, callbacks, conflicts, arcs, people, and evidence fragments extracted from real creator archives.",
      primary: "Search the atlas",
      secondary: "Watch the timeline",
      search_label: "Search creator lore",
      search_placeholder: "Try a meme, phrase, person, conflict, or callback",
      search_button: "Search",
      search_hint:
        "Examples: meme origin, repeated phrase, conflict, game arc, person nickname, forgotten callback.",
      search_results: "Search Results",
      no_search_results:
        "No exact public results yet. The atlas keeps growing as sources are processed.",
      entities_found: "Entities",
      events_found: "Events",
      fragments_found: "Evidence fragments",
      map_label: "live universe map",
      map_title: "Narrative Constellation",
      indexing: "indexing",
      map_note:
        "New fragments extend the graph with mentions, callbacks, origin points, and evolving meme branches.",
      study_eyebrow: "background study",
      study_title: "The atlas grows while people watch.",
      study_text:
        "Sources are registered by admins, workers collect videos and transcripts in the background, AI windows extract lore, and the public portal exposes what becomes stable enough to inspect.",
      pipeline: "Daily crawl pipeline",
      planned: "planned",
      known_links: "Known Lore Links",
      active_memes: "Active Memes",
      timeline: "Lore Timeline",
      sources_title: "Sources Being Studied",
      fragments: "Fresh Fragments",
      stat_sources: "Sources",
      stat_videos: "Videos",
      stat_segments: "Transcript rows",
      stat_entities: "Lore entities",
      stat_memes: "Memes",
      stat_events: "Events",
      stat_edges: "Links",
      portal_deck: "What this portal gives people",
      portal_deck_text:
        "A viewer can ask when a meme appeared, why a phrase keeps returning, which events connect across years, and what evidence the system used. It turns thousands of videos into a browsable cultural memory.",
      source_coverage: "Source coverage",
      transcript_depth: "Transcript depth",
      lore_memory: "Lore memory",
      scale_note:
        "Designed for tens of thousands of videos: work is queued, deduplicated, priced, and projected into persistent graph tables.",
      cost_note: "AI spend is tracked in the admin console before public expansion.",
      relationships: "relationships",
      evidence: "evidence",
      intensity: "intensity"
    }
  end

  def home_copy(_locale) do
    %{
      brand: "Геном Стрима",
      explore: "Атлас",
      sources: "Источники",
      eyebrow: "публичный атлас лора авторов",
      headline: "Вселенная автора как живая карта мемов.",
      lead:
        "Ищите мемы, фразы, колбэки, конфликты, арки, людей и доказательные фрагменты, извлеченные из реальных архивов контента.",
      primary: "Искать в атласе",
      secondary: "Смотреть таймлайн",
      search_label: "Поиск по лору",
      search_placeholder: "Введите мем, фразу, человека, конфликт или колбэк",
      search_button: "Найти",
      search_hint:
        "Например: происхождение мема, повторяющаяся фраза, конфликт, игровая арка, никнейм, забытый колбэк.",
      search_results: "Результаты поиска",
      no_search_results:
        "Точных публичных результатов пока нет. Атлас пополняется по мере обработки источников.",
      entities_found: "Сущности",
      events_found: "События",
      fragments_found: "Доказательные фрагменты",
      map_label: "живая карта вселенной",
      map_title: "Нарративное созвездие",
      indexing: "индексация",
      map_note:
        "Новые фрагменты расширяют граф упоминаниями, отсылками, точками происхождения и ветками эволюции мемов.",
      study_eyebrow: "фоновое изучение",
      study_title: "Атлас растет, пока люди смотрят.",
      study_text:
        "Источники добавляет админ, воркеры фоном собирают видео и транскрипты, AI-окна извлекают лор, а публичный портал показывает то, что стало достаточно устойчивым для просмотра.",
      pipeline: "Ежедневный пайплайн",
      planned: "планируется",
      known_links: "Связи лора",
      active_memes: "Активные мемы",
      timeline: "Таймлайн лора",
      sources_title: "Изучаемые источники",
      fragments: "Свежие фрагменты",
      stat_sources: "Источники",
      stat_videos: "Видео",
      stat_segments: "Строки транскриптов",
      stat_entities: "Сущности лора",
      stat_memes: "Мемы",
      stat_events: "События",
      stat_edges: "Связи",
      portal_deck: "Что портал дает людям",
      portal_deck_text:
        "Зритель может понять, когда появился мем, почему фраза возвращается, какие события связаны через годы и на каких фрагментах основаны выводы системы. Тысячи видео превращаются в просматриваемую культурную память.",
      source_coverage: "Покрытие источников",
      transcript_depth: "Глубина транскриптов",
      lore_memory: "Память лора",
      scale_note:
        "Архитектура рассчитана на десятки тысяч видео: задачи ставятся в очереди, дубли отсекаются, расходы считаются, результат проецируется в постоянный граф.",
      cost_note: "Расходы AI отслеживаются в админке до публичного масштабирования.",
      relationships: "связей",
      evidence: "доказательство",
      intensity: "интенсивность"
    }
  end

  def percent(nil), do: "0%"
  def percent(value), do: "#{round(value * 100)}%"

  def format_date(nil), do: "unknown"

  def format_date(%DateTime{} = value) do
    Calendar.strftime(value, "%Y-%m-%d")
  end

  def format_offset(nil), do: "00:00"

  def format_offset(milliseconds) do
    total_seconds = div(milliseconds, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)

    "#{pad2(minutes)}:#{pad2(seconds)}"
  end

  def featured_meme(%{memes: [meme | _]}, locale), do: public_text(meme.canonical_name, locale)
  def featured_meme(_snapshot, "ru"), do: "Ожидаем первый мем-сигнал"
  def featured_meme(_snapshot, _locale), do: "Awaiting the first meme signal"

  def public_text(nil, _locale), do: ""
  def public_text(value, "ru"), do: to_string(value)

  def public_text(value, "en") do
    value = to_string(value)

    if cyrillic?(value) do
      transliterate_cyrillic(value)
    else
      value
    end
  end

  def public_text(value, _locale), do: to_string(value)

  def search_total(%{entities: entities, events: events, segments: segments}) do
    length(entities) + length(events) + length(segments)
  end

  defp pad2(value) when value < 10, do: "0#{value}"
  defp pad2(value), do: to_string(value)

  defp cyrillic?(value), do: Regex.match?(~r/[А-Яа-яЁё]/u, value)

  defp transliterate_cyrillic(value) do
    value
    |> String.graphemes()
    |> Enum.map_join(&Map.get(transliteration_map(), &1, &1))
  end

  defp transliteration_map do
    %{
      "А" => "A",
      "Б" => "B",
      "В" => "V",
      "Г" => "G",
      "Д" => "D",
      "Е" => "E",
      "Ё" => "Yo",
      "Ж" => "Zh",
      "З" => "Z",
      "И" => "I",
      "Й" => "Y",
      "К" => "K",
      "Л" => "L",
      "М" => "M",
      "Н" => "N",
      "О" => "O",
      "П" => "P",
      "Р" => "R",
      "С" => "S",
      "Т" => "T",
      "У" => "U",
      "Ф" => "F",
      "Х" => "Kh",
      "Ц" => "Ts",
      "Ч" => "Ch",
      "Ш" => "Sh",
      "Щ" => "Shch",
      "Ъ" => "",
      "Ы" => "Y",
      "Ь" => "",
      "Э" => "E",
      "Ю" => "Yu",
      "Я" => "Ya",
      "а" => "a",
      "б" => "b",
      "в" => "v",
      "г" => "g",
      "д" => "d",
      "е" => "e",
      "ё" => "yo",
      "ж" => "zh",
      "з" => "z",
      "и" => "i",
      "й" => "y",
      "к" => "k",
      "л" => "l",
      "м" => "m",
      "н" => "n",
      "о" => "o",
      "п" => "p",
      "р" => "r",
      "с" => "s",
      "т" => "t",
      "у" => "u",
      "ф" => "f",
      "х" => "kh",
      "ц" => "ts",
      "ч" => "ch",
      "ш" => "sh",
      "щ" => "shch",
      "ъ" => "",
      "ы" => "y",
      "ь" => "",
      "э" => "e",
      "ю" => "yu",
      "я" => "ya"
    }
  end
end
