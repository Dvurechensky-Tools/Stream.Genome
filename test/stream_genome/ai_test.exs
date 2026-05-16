defmodule StreamGenome.AITest do
  use StreamGenome.DataCase, async: false

  setup do
    original = Application.get_env(:stream_genome, :ai)

    on_exit(fn ->
      Application.put_env(:stream_genome, :ai, original)
    end)

    :ok
  end

  test "OpenAI endpoint is not enabled without an API key" do
    Application.put_env(:stream_genome, :ai,
      provider: :openai_compatible,
      endpoint: "https://api.openai.com/v1/chat/completions",
      model: "gpt-4o-mini",
      api_key: nil
    )

    assert %{enabled?: false, api_key_configured?: false} = StreamGenome.AI.settings()
    assert {:error, :ai_provider_not_configured} = StreamGenome.AI.complete("hello")
  end

  test "OpenAI-compatible local endpoints can run without an API key" do
    Application.put_env(:stream_genome, :ai,
      provider: :openai_compatible,
      endpoint: "http://llm-gateway:8080/v1/chat/completions",
      model: "local-model",
      api_key: nil
    )

    assert %{enabled?: true, api_key_configured?: false} = StreamGenome.AI.settings()
  end
end
