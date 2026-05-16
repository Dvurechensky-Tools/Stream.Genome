defmodule StreamGenome.AI.Provider do
  @moduledoc """
  Behaviour for model providers used by the intelligence stages.
  """

  @callback complete(prompt :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}
end
