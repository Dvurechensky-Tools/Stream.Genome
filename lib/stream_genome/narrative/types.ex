defmodule StreamGenome.Narrative.Types do
  @moduledoc """
  Enumerations used by the persistent creator-universe model.
  """

  @source_types ~w(youtube twitch kick podcast tiktok discord telegram reddit youtube_comments twitch_chat)
  @content_kinds ~w(video vod stream podcast clip thread comment_export chat_export transcript)
  @segment_types ~w(transcript chat ocr comment metadata)
  @entity_types ~w(person meme event phrase community stream conflict arc topic)
  @edge_types ~w(references evolved_into originated_from emotionally_linked triggered repeated_by associated_with)
  @event_types ~w(origin callback revival decline conflict hype controversy community_shift arc_turn)
  @observation_types ~w(mention quote reaction sentiment emotion callback)
  @meme_statuses ~w(emerging growing stable declining dormant revived dead)

  def source_types, do: @source_types
  def content_kinds, do: @content_kinds
  def segment_types, do: @segment_types
  def entity_types, do: @entity_types
  def edge_types, do: @edge_types
  def event_types, do: @event_types
  def observation_types, do: @observation_types
  def meme_statuses, do: @meme_statuses
end
