defmodule StreamGenome.Crawler.Setting do
  @moduledoc """
  Persistent crawler runtime settings controlled from the admin UI.
  """

  use StreamGenome.Narrative.Schema

  schema "crawler_settings" do
    field :key, :string
    field :value, :map, default: %{}

    timestamps()
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value])
    |> validate_required([:key, :value])
    |> unique_constraint(:key)
  end
end
