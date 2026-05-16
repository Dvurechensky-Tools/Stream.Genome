defmodule StreamGenome.AI.OllamaProvider do
  @moduledoc """
  Ollama-backed local inference provider.
  """

  @behaviour StreamGenome.AI.Provider

  @impl true
  def complete(prompt, opts) do
    endpoint = Keyword.get(opts, :endpoint, "http://localhost:11434/api/generate")
    model = Keyword.get(opts, :model, "llama3.1")

    case Req.post(endpoint,
           json: %{model: model, prompt: prompt, stream: false},
           receive_timeout: Keyword.get(opts, :timeout_ms, 120_000),
           retry: false
         ) do
      {:ok, %{status: status, body: %{"response" => response}}} when status in 200..299 ->
        {:ok, %{content: response, usage: %{}, model: model}}

      {:ok, response} ->
        {:error, {:unexpected_response, response.status, response.body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
