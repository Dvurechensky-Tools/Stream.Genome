defmodule StreamGenome.Ingestion.Broadway.ManifestPipeline do
  @moduledoc """
  Broadway pipeline for normalized ingestion manifests.

  It is intentionally not supervised by default; production deployments can wire
  the producer to SQS, RabbitMQ, Kafka, or an internal producer.
  """

  use Broadway

  alias Broadway.Message
  alias StreamGenome.Ingestion.Workers.IngestManifestWorker

  def start_link(opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: Keyword.fetch!(opts, :producer),
      processors: [default: [concurrency: Keyword.get(opts, :processor_concurrency, 5)]]
    )
  end

  @impl Broadway
  def handle_message(_, %Message{data: manifest} = message, _) do
    %{manifest: manifest}
    |> IngestManifestWorker.new()
    |> Oban.insert()

    message
  end
end
