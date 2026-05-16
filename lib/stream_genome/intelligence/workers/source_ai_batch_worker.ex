defmodule StreamGenome.Intelligence.Workers.SourceAIBatchWorker do
  @moduledoc """
  Keeps feeding completed transcript windows into AI extraction in controlled waves.
  """

  use Oban.Worker, queue: :intelligence, max_attempts: 1

  alias StreamGenome.Intelligence

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "source_id" => source_id,
          "window_count" => window_count,
          "batches_remaining" => batches_remaining,
          "interval_seconds" => interval_seconds
        }
      }) do
    snapshot = Intelligence.source_snapshot(source_id)

    cond do
      batches_remaining <= 0 ->
        :ok

      snapshot.pending_segments <= 0 ->
        :ok

      snapshot.runs_queued + snapshot.runs_awaiting_model > 0 ->
        schedule_next(source_id, window_count, batches_remaining, interval_seconds)

      true ->
        {:ok, %{runs: runs}} =
          Intelligence.queue_source_extraction_windows(source_id, limit: window_count)

        if runs == [] do
          :ok
        else
          schedule_next(source_id, window_count, batches_remaining - 1, interval_seconds)
        end
    end
  end

  defp schedule_next(_source_id, _window_count, batches_remaining, _interval_seconds)
       when batches_remaining <= 0,
       do: :ok

  defp schedule_next(source_id, window_count, batches_remaining, interval_seconds) do
    %{
      source_id: source_id,
      window_count: window_count,
      batches_remaining: batches_remaining,
      interval_seconds: interval_seconds
    }
    |> __MODULE__.new(schedule_in: interval_seconds)
    |> Oban.insert()

    :ok
  end
end
