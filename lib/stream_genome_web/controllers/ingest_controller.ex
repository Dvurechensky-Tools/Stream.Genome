defmodule StreamGenomeWeb.IngestController do
  use StreamGenomeWeb, :controller

  alias StreamGenome.ManualIngest

  def new(conn, _params) do
    render(conn, :new, sample_text: ManualIngest.sample_text(), text: "")
  end

  def create(conn, %{"ingest" => %{"text" => text}}) do
    case ManualIngest.ingest(text) do
      {:ok, result} ->
        conn
        |> put_flash(
          :info,
          "Saved #{length(result.segments)} lines and detected #{length(result.phrases)} phrase candidates."
        )
        |> redirect(to: ~p"/admin")

      {:error, :empty_text} ->
        conn
        |> put_flash(:error, "Paste at least one line.")
        |> render(:new, sample_text: ManualIngest.sample_text(), text: text)
    end
  end
end
