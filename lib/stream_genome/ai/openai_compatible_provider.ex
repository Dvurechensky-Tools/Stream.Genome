defmodule StreamGenome.AI.OpenAICompatibleProvider do
  @moduledoc """
  OpenAI-compatible chat completions provider.
  """

  @behaviour StreamGenome.AI.Provider

  @impl true
  def complete(prompt, opts) do
    endpoint = Keyword.fetch!(opts, :endpoint)
    api_key = Keyword.get(opts, :api_key)
    model = Keyword.fetch!(opts, :model)

    headers =
      if api_key do
        [{"authorization", "Bearer #{api_key}"}, {"content-type", "application/json"}]
      else
        [{"content-type", "application/json"}]
      end

    body = %{
      model: model,
      messages: [%{role: "user", content: prompt}],
      temperature: Keyword.get(opts, :temperature, 0.2)
    }

    case Req.post(endpoint,
           headers: headers,
           json: body,
           receive_timeout: Keyword.get(opts, :timeout_ms, 120_000),
           retry: false
         ) do
      {:ok,
       %{
         status: status,
         body: %{"choices" => [%{"message" => %{"content" => content}} | _]} = response_body
       }}
      when status in 200..299 ->
        {:ok,
         %{
           content: content,
           usage: Map.get(response_body, "usage", %{}),
           model: Map.get(response_body, "model", model)
         }}

      {:ok, response} ->
        {:error, {:unexpected_response, response.status, response.body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
