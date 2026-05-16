defmodule StreamGenome.AI do
  @moduledoc """
  Runtime access to configured model providers.
  """

  alias StreamGenome.AI.{OllamaProvider, OpenAICompatibleProvider}
  alias StreamGenome.Crawler.Setting
  alias StreamGenome.Repo

  @settings_key "ai"

  def settings do
    configured = effective_config()

    %{
      provider: Keyword.get(configured, :provider, :disabled),
      endpoint: Keyword.get(configured, :endpoint),
      model: Keyword.get(configured, :model),
      api_key_configured?: configured |> Keyword.get(:api_key) |> present?(),
      temperature: Keyword.get(configured, :temperature, 0.2),
      timeout_ms: Keyword.get(configured, :timeout_ms, 120_000),
      input_usd_per_1m: Keyword.get(configured, :input_usd_per_1m, 0.15),
      output_usd_per_1m: Keyword.get(configured, :output_usd_per_1m, 0.60),
      enabled?: enabled?(configured)
    }
  end

  def form_settings do
    configured = effective_config()

    %{
      "provider" => configured |> Keyword.get(:provider, :disabled) |> Atom.to_string(),
      "endpoint" => Keyword.get(configured, :endpoint),
      "model" => Keyword.get(configured, :model),
      "temperature" => configured |> Keyword.get(:temperature, 0.2) |> to_string(),
      "timeout_ms" => configured |> Keyword.get(:timeout_ms, 120_000) |> to_string(),
      "input_usd_per_1m" => configured |> Keyword.get(:input_usd_per_1m, 0.15) |> to_string(),
      "output_usd_per_1m" => configured |> Keyword.get(:output_usd_per_1m, 0.60) |> to_string(),
      "api_key_configured" => configured |> Keyword.get(:api_key) |> present?()
    }
  end

  def update_settings(attrs) do
    previous = effective_config()

    api_key =
      attrs
      |> Map.get("api_key", "")
      |> to_string()
      |> String.trim()
      |> case do
        "" -> Keyword.get(previous, :api_key)
        value -> value
      end

    value = %{
      "provider" => normalize_provider(attrs["provider"]),
      "endpoint" => attrs["endpoint"] |> to_string() |> String.trim(),
      "model" => attrs["model"] |> to_string() |> String.trim(),
      "api_key" => api_key,
      "temperature" => parse_temperature(attrs["temperature"]),
      "timeout_ms" => parse_timeout(attrs["timeout_ms"]),
      "input_usd_per_1m" => parse_price(attrs["input_usd_per_1m"], 0.15),
      "output_usd_per_1m" => parse_price(attrs["output_usd_per_1m"], 0.60)
    }

    setting = Repo.get_by(Setting, key: @settings_key) || %Setting{key: @settings_key}

    setting
    |> Setting.changeset(%{key: @settings_key, value: value})
    |> Repo.insert_or_update()
  end

  def complete(prompt, opts \\ []) when is_binary(prompt) do
    case complete_with_metadata(prompt, opts) do
      {:ok, %{content: content}} -> {:ok, content}
      {:error, reason} -> {:error, reason}
    end
  end

  def complete_with_metadata(prompt, opts \\ []) when is_binary(prompt) do
    configured = effective_config()
    provider = Keyword.get(configured, :provider, :disabled)
    provider_opts = Keyword.merge(configured, opts)

    cond do
      provider == :disabled ->
        {:error, :ai_provider_disabled}

      not enabled?(configured) ->
        {:error, :ai_provider_not_configured}

      true ->
        provider
        |> provider_module()
        |> apply(:complete, [prompt, provider_opts])
        |> attach_cost(provider_opts)
    end
  end

  def estimate_cost(usage, opts) when is_map(usage) do
    input_tokens = token_value(usage, "prompt_tokens") || token_value(usage, :prompt_tokens) || 0

    output_tokens =
      token_value(usage, "completion_tokens") || token_value(usage, :completion_tokens) || 0

    input_price = Keyword.get(opts, :input_usd_per_1m, 0.15)
    output_price = Keyword.get(opts, :output_usd_per_1m, 0.60)

    input_tokens / 1_000_000 * input_price + output_tokens / 1_000_000 * output_price
  end

  def estimate_cost(_usage, _opts), do: 0.0

  defp enabled?(configured) do
    case Keyword.get(configured, :provider, :disabled) do
      :disabled ->
        false

      :openai_compatible ->
        endpoint = Keyword.get(configured, :endpoint)

        present?(endpoint) and present?(Keyword.get(configured, :model)) and
          (not openai_endpoint?(endpoint) or present?(Keyword.get(configured, :api_key)))

      :ollama ->
        present?(Keyword.get(configured, :endpoint)) and present?(Keyword.get(configured, :model))
    end
  end

  defp provider_module(:openai_compatible), do: OpenAICompatibleProvider
  defp provider_module(:ollama), do: OllamaProvider

  defp openai_endpoint?(endpoint) when is_binary(endpoint),
    do: String.contains?(endpoint, "api.openai.com")

  defp openai_endpoint?(_endpoint), do: false

  defp effective_config do
    defaults = Application.get_env(:stream_genome, :ai, [])

    case Repo.get_by(Setting, key: @settings_key) do
      %Setting{value: value} -> merge_setting(defaults, value || %{})
      nil -> defaults
    end
  rescue
    _error -> Application.get_env(:stream_genome, :ai, [])
  end

  defp merge_setting(defaults, value) do
    [
      provider:
        value
        |> Map.get("provider", defaults |> Keyword.get(:provider, :disabled) |> Atom.to_string())
        |> provider_atom(),
      endpoint: Map.get(value, "endpoint", Keyword.get(defaults, :endpoint)),
      model: Map.get(value, "model", Keyword.get(defaults, :model)),
      api_key: Map.get(value, "api_key", Keyword.get(defaults, :api_key)),
      temperature: Map.get(value, "temperature", Keyword.get(defaults, :temperature, 0.2)),
      timeout_ms: Map.get(value, "timeout_ms", Keyword.get(defaults, :timeout_ms, 120_000)),
      input_usd_per_1m:
        Map.get(value, "input_usd_per_1m", Keyword.get(defaults, :input_usd_per_1m, 0.15)),
      output_usd_per_1m:
        Map.get(value, "output_usd_per_1m", Keyword.get(defaults, :output_usd_per_1m, 0.60))
    ]
  end

  defp normalize_provider("openai"), do: "openai_compatible"
  defp normalize_provider("openai_compatible"), do: "openai_compatible"
  defp normalize_provider("ollama"), do: "ollama"
  defp normalize_provider(_other), do: "disabled"

  defp provider_atom("openai_compatible"), do: :openai_compatible
  defp provider_atom("openai"), do: :openai_compatible
  defp provider_atom("ollama"), do: :ollama
  defp provider_atom(_other), do: :disabled

  defp parse_temperature(value) do
    value
    |> to_string()
    |> Float.parse()
    |> case do
      {temperature, ""} when temperature >= 0.0 and temperature <= 2.0 -> temperature
      _other -> 0.2
    end
  end

  defp parse_timeout(value) do
    value
    |> to_string()
    |> Integer.parse()
    |> case do
      {timeout_ms, ""} when timeout_ms >= 5_000 and timeout_ms <= 600_000 -> timeout_ms
      _other -> 120_000
    end
  end

  defp parse_price(value, default) do
    value
    |> to_string()
    |> Float.parse()
    |> case do
      {price, ""} when price >= 0.0 -> price
      _other -> default
    end
  end

  defp attach_cost({:ok, response}, opts) when is_map(response) do
    usage = Map.get(response, :usage) || Map.get(response, "usage") || %{}

    {:ok,
     response
     |> Map.put(:usage, usage)
     |> Map.put(:estimated_cost_usd, estimate_cost(usage, opts))
     |> Map.put(:pricing, %{
       input_usd_per_1m: Keyword.get(opts, :input_usd_per_1m, 0.15),
       output_usd_per_1m: Keyword.get(opts, :output_usd_per_1m, 0.60)
     })}
  end

  defp attach_cost(other, _opts), do: other

  defp token_value(usage, key) do
    case Map.get(usage, key) do
      value when is_integer(value) -> value
      value when is_float(value) -> round(value)
      _other -> nil
    end
  end

  defp present?(value) when value in [nil, ""], do: false
  defp present?(_value), do: true
end
