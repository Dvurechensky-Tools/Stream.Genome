defmodule StreamGenome.Ingestion.Manifest do
  @moduledoc """
  Validated ingestion manifest for one content item.
  """

  @required [:source, :content]

  def validate(attrs) when is_map(attrs) do
    missing = Enum.reject(@required, &Map.has_key?(attrs, &1))

    if missing == [] do
      {:ok, attrs}
    else
      {:error, {:missing_keys, missing}}
    end
  end
end
