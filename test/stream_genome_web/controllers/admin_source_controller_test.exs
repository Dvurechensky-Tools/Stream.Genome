defmodule StreamGenomeWeb.AdminSourceControllerTest do
  use StreamGenomeWeb.ConnCase

  alias StreamGenome.Narrative
  alias StreamGenome.Narrative.{ContentItem, SourceScanRun}
  alias StreamGenome.Repo

  setup do
    {:ok, source} =
      Narrative.create_source(%{
        name: "@ExampleChannel",
        source_type: "youtube",
        external_id: "@examplechannel",
        url: "https://www.youtube.com/@ExampleChannel"
      })

    %{source: source}
  end

  test "GET /admin/sources/:id renders source detail", %{conn: conn, source: source} do
    conn = get(conn, ~p"/admin/sources/#{source.id}")
    response = html_response(conn, 200)

    assert response =~ "@ExampleChannel"
    assert response =~ "Start Scan"
    assert response =~ "No scans yet"
  end

  test "POST /admin/sources/:id/scan queues scan run", %{conn: conn, source: source} do
    conn = post(conn, ~p"/admin/sources/#{source.id}/scan")

    assert redirected_to(conn) == ~p"/admin/sources/#{source.id}"
    assert [%SourceScanRun{status: "queued"}] = Repo.all(SourceScanRun)
  end

  test "POST /admin/sources/:id/transcripts queues transcript jobs", %{conn: conn, source: source} do
    {:ok, item} =
      Narrative.create_content_item(%{
        source_id: source.id,
        kind: "video",
        external_id: "abc123",
        title: "Video",
        url: "https://www.youtube.com/watch?v=abc123"
      })

    conn = post(conn, ~p"/admin/sources/#{source.id}/transcripts", %{"limit" => "1"})

    assert redirected_to(conn) == ~p"/admin/sources/#{source.id}"

    item = Repo.get!(ContentItem, item.id)
    assert item.metadata["transcript_status"] == "queued"
  end

  test "POST /admin/sources/:id/transcripts/auto queues auto batch worker", %{
    conn: conn,
    source: source
  } do
    conn =
      post(conn, ~p"/admin/sources/#{source.id}/transcripts/auto", %{
        "batch" => %{"size" => "3", "count" => "2"}
      })

    assert redirected_to(conn) == ~p"/admin/sources/#{source.id}"
  end

  test "POST /admin/sources/:id/intelligence/windows queues extraction windows", %{
    conn: conn,
    source: source
  } do
    {:ok, item} =
      Narrative.create_content_item(%{
        source_id: source.id,
        kind: "video",
        external_id: "abc123",
        title: "Video",
        url: "https://www.youtube.com/watch?v=abc123"
      })

    {:ok, _segment} =
      Narrative.create_segment(%{
        content_item_id: item.id,
        segment_type: "transcript",
        body: "Привет, это тестовый мемный кусок.",
        language: "ru",
        starts_at_ms: 1_000,
        ends_at_ms: 4_000
      })

    conn = post(conn, ~p"/admin/sources/#{source.id}/intelligence/windows", %{"limit" => "1"})

    assert redirected_to(conn) == ~p"/admin/sources/#{source.id}"
  end
end
