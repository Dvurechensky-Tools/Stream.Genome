defmodule StreamGenome.Crawler.Workers.SourceTranscriptBatchWorker do
  @moduledoc """
  Keeps feeding transcript jobs in controlled batches for a source.
  """

  use Oban.Worker, queue: :crawler, max_attempts: 1

  alias StreamGenome.Narrative

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "source_id" => source_id,
          "batch_size" => batch_size,
          "batches_remaining" => batches_remaining,
          "interval_seconds" => interval_seconds
        }
      }) do
    snapshot = Narrative.source_transcript_snapshot(source_id)

    cond do
      batches_remaining <= 0 ->
        :ok

      snapshot.pending <= 0 ->
        :ok

      snapshot.queued + snapshot.running > 0 ->
        schedule_next(source_id, batch_size, batches_remaining, interval_seconds)

      true ->
        {:ok, %{videos: videos}} =
          Narrative.queue_source_transcripts(source_id, limit: batch_size)

        if videos == [] do
          :ok
        else
          schedule_next(source_id, batch_size, batches_remaining - 1, interval_seconds)
        end
    end
  end

  defp schedule_next(_source_id, _batch_size, batches_remaining, _interval_seconds)
       when batches_remaining <= 0,
       do: :ok

  defp schedule_next(source_id, batch_size, batches_remaining, interval_seconds) do
    %{
      source_id: source_id,
      batch_size: batch_size,
      batches_remaining: batches_remaining,
      interval_seconds: interval_seconds
    }
    |> __MODULE__.new(schedule_in: interval_seconds)
    |> Oban.insert()

    :ok
  end
end
