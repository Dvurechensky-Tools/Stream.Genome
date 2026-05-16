defmodule StreamGenome.Ingestion.Workers.IngestManifestWorker do
  @moduledoc """
  Persists an ingestion manifest and schedules intelligence work.
  """

  use Oban.Worker, queue: :ingestion, max_attempts: 3

  alias StreamGenome.{Narrative, Repo}
  alias StreamGenome.Ingestion.Manifest
  alias StreamGenome.Intelligence.Workers.ExtractSegmentWorker

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"manifest" => manifest}}) do
    manifest = atomize_keys(manifest)

    with {:ok, manifest} <- Manifest.validate(manifest) do
      Repo.transaction(fn ->
        {:ok, source} = Narrative.create_source(manifest.source)

        {:ok, item} =
          manifest.content |> Map.put(:source_id, source.id) |> Narrative.create_content_item()

        manifest
        |> Map.get(:segments, [])
        |> Enum.each(fn segment_attrs ->
          {:ok, segment} =
            segment_attrs
            |> Map.put(:content_item_id, item.id)
            |> Narrative.create_segment()

          %{segment_id: segment.id}
          |> ExtractSegmentWorker.new()
          |> Oban.insert!()
        end)
      end)

      :ok
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {known_key(key), atomize_keys(value)} end)
  end

  defp atomize_keys(list) when is_list(list), do: Enum.map(list, &atomize_keys/1)
  defp atomize_keys(value), do: value

  defp known_key(key) when is_atom(key), do: key

  defp known_key(key)
       when key in ~w(source content segments name source_type external_id url metadata kind title
              published_at duration_ms language segment_type speaker_label body starts_at_ms ends_at_ms occurred_at) do
    String.to_existing_atom(key)
  end

  defp known_key(key), do: key
end
