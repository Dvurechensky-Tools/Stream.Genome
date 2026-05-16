defmodule StreamGenome.Narrative.Schema do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema

      import Ecto.Changeset

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
      @timestamps_opts [type: :utc_datetime_usec]
    end
  end

  def validate_inclusion(changeset, field, values) do
    Ecto.Changeset.validate_inclusion(changeset, field, values)
  end
end
