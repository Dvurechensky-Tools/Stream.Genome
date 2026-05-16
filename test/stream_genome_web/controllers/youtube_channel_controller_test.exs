defmodule StreamGenomeWeb.YouTubeChannelControllerTest do
  use StreamGenomeWeb.ConnCase

  test "GET /admin/youtube/channel renders channel form", %{conn: conn} do
    conn = get(conn, ~p"/admin/youtube/channel")

    response = html_response(conn, 200)
    assert response =~ "YouTube Channel Source"
    assert response =~ "Register Channel"
  end

  test "POST /admin/youtube/channel registers source and redirects to source detail", %{
    conn: conn
  } do
    conn =
      post(conn, ~p"/admin/youtube/channel", %{
        "youtube_channel" => %{"url" => "https://www.youtube.com/@ExampleChannel"}
      })

    assert redirected_to(conn) =~ "/admin/sources/"
  end
end
