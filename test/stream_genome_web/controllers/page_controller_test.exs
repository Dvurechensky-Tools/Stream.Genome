defmodule StreamGenomeWeb.PageControllerTest do
  use StreamGenomeWeb.ConnCase

  test "GET / renders the Russian public portal by default", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "Геном Стрима"
    assert response =~ "Поиск по лору"
    assert response =~ "RU"
    assert response =~ "EN"
    refute response =~ "Add YouTube"
    refute response =~ "Paste Fragment"
  end

  test "GET / supports English public copy", %{conn: conn} do
    conn = get(conn, ~p"/?lang=en")
    response = html_response(conn, 200)

    assert response =~ "Stream Genome"
    assert response =~ "public creator lore atlas"
    assert response =~ "Explore Atlas"
  end

  test "GET / supports public lore search", %{conn: conn} do
    StreamGenome.Demo.load!()

    conn = get(conn, ~p"/?lang=en&q=Chair")
    response = html_response(conn, 200)

    assert response =~ "Search Results"
    assert response =~ "Chair Arc"
    assert response =~ "Evidence fragments"
  end

  test "GET / renders demo lore when seeded", %{conn: conn} do
    StreamGenome.Demo.load!()

    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "Chair Arc"
    assert response =~ "Sandwich Tribunal"
    assert response =~ "references"
  end
end
