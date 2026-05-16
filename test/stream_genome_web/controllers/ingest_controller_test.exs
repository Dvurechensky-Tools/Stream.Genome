defmodule StreamGenomeWeb.IngestControllerTest do
  use StreamGenomeWeb.ConnCase

  test "GET /admin/ingest renders manual ingest form", %{conn: conn} do
    conn = get(conn, ~p"/admin/ingest")

    response = html_response(conn, 200)
    assert response =~ "Manual Stream Fragment"
    assert response =~ "Save Fragment"
  end

  test "POST /admin/ingest saves fragment and redirects to admin console", %{conn: conn} do
    conn =
      post(conn, ~p"/admin/ingest", %{
        "ingest" => %{
          "text" => """
          Streamer: Chair arc returns.
          Chat: CHAIR ARC
          """
        }
      })

    assert redirected_to(conn) == ~p"/admin"
  end
end
