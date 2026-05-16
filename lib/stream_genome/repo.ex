defmodule StreamGenome.Repo do
  use Ecto.Repo,
    otp_app: :stream_genome,
    adapter: Ecto.Adapters.Postgres
end
