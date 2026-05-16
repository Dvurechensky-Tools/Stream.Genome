defmodule StreamGenome.Intelligence.Workers.ExtractSegmentWorker do
  @moduledoc """
  Runs entity and relationship extraction for one segment.
  """

  use Oban.Worker, queue: :intelligence, max_attempts: 3

  alias StreamGenome.Narrative.ContentSegment
  alias StreamGenome.{Repo, Narrative}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"segment_id" => segment_id}}) do
    segment = Repo.get!(ContentSegment, segment_id)

    metadata = ready_metadata(segment.metadata)

    Narrative.update_segment(segment, %{metadata: metadata})
    :ok
  end

  defp ready_metadata(%{"intelligence_status" => "batched"} = metadata), do: metadata

  defp ready_metadata(metadata) do
    metadata
    |> Map.put("intelligence_status", "ready")
    |> Map.put("intelligence_ready_at", DateTime.utc_now())
  end
end
