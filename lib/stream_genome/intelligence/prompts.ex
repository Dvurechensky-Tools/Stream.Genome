defmodule StreamGenome.Intelligence.Prompts do
  @moduledoc """
  Prompt builders for narrative extraction tasks.
  """

  def entity_extraction(segment_text) do
    """
    Extract creator-universe entities from this segment.

    Return compact JSON with keys: people, memes, phrases, conflicts, topics, emotional_markers.
    Include aliases and confidence when visible from the text.

    Segment:
    #{segment_text}
    """
  end

  def lore_extraction_window(window_text, language) do
    """
    You are extracting durable creator-universe lore from a transcript window.

    Source language: #{language}

    Return compact JSON with keys:
    people, memes, phrases, topics, conflicts, emotional_markers, callbacks, candidate_events.

    Rules:
    - Preserve original-language quotes and meme phrases.
    - Add short English glosses only when useful.
    - Prefer recurring or narratively meaningful signals over generic gameplay text.
    - Include confidence values from 0.0 to 1.0.
    - Mention segment timestamps as evidence when possible.

    Transcript window:
    #{window_text}
    """
  end

  def callback_detection(current_text, historical_summary) do
    """
    Decide whether the current segment references older creator lore.

    Return compact JSON with keys: is_callback, referenced_lore, age_hint, confidence, explanation.

    Historical lore:
    #{historical_summary}

    Current segment:
    #{current_text}
    """
  end
end
