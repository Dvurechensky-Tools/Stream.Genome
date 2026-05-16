defmodule StreamGenomeWeb.AdminControllerTest do
  use StreamGenomeWeb.ConnCase

  test "GET /admin renders operational console", %{conn: conn} do
    conn = get(conn, ~p"/admin")
    response = html_response(conn, 200)

    assert response =~ "Admin Console"
    assert response =~ "AI Provider"
    assert response =~ "Save AI Provider"
    assert response =~ "Register YouTube channel"
    assert response =~ "Paste manual fragment"
  end

  test "POST /admin/ai-settings saves provider settings", %{conn: conn} do
    conn =
      post(conn, ~p"/admin/ai-settings", %{
        "ai_settings" => %{
          "provider" => "openai_compatible",
          "endpoint" => "https://api.openai.com/v1/chat/completions",
          "model" => "gpt-4o-mini",
          "temperature" => "0.1",
          "api_key" => "test-key"
        }
      })

    assert redirected_to(conn) == ~p"/admin"

    assert %{enabled?: true, api_key_configured?: true, model: "gpt-4o-mini"} =
             StreamGenome.AI.settings()
  end
end
