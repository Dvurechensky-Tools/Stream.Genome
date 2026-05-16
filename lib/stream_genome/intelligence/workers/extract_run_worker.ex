defmodule StreamGenome.Intelligence.Workers.ExtractRunWorker do
  @moduledoc """
  Sends a durable extraction run to the configured AI provider.
  """

  use Oban.Worker, queue: :intelligence, max_attempts: 2

  require Logger

  alias StreamGenome.{AI, Intelligence}
  alias StreamGenome.Intelligence.ResultProjector

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"run_id" => run_id}}) do
    run = Intelligence.get_extraction_run!(run_id)

    case Intelligence.mark_extraction_run_started(run) do
      {:ok, started_run} -> call_model(started_run)
      {:error, reason} -> {:error, reason}
    end
  end

  defp call_model(run) do
    case AI.complete_with_metadata(run.prompt) do
      {:ok, response} ->
        {:ok, completed_run} =
          Intelligence.mark_extraction_run_completed(run, parse_result(response.content), %{
            ai_usage: response.usage,
            ai_model: Map.get(response, :model),
            ai_cost_usd: response.estimated_cost_usd,
            ai_pricing: response.pricing
          })

        ResultProjector.project_run(completed_run)
        :ok

      {:error, reason} ->
        Intelligence.mark_extraction_run_failed(run, inspect(reason, limit: :infinity))
        Logger.warning("AI extraction run #{run.id} failed: #{inspect(reason, limit: :infinity)}")
        :ok
    end
  end

  defp parse_result(content) do
    content
    |> strip_code_fence()
    |> Jason.decode()
    |> case do
      {:ok, decoded} -> decoded
      {:error, _reason} -> %{"raw_text" => content}
    end
  end

  defp strip_code_fence(content) do
    content
    |> String.trim()
    |> String.replace_prefix("```json", "")
    |> String.replace_prefix("```", "")
    |> String.replace_suffix("```", "")
    |> String.trim()
  end
end
