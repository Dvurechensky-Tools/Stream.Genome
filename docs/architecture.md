# Architecture

## System Shape

Stream.Genome is an evented narrative intelligence system.

PostgreSQL stores the durable source of truth: content, segments, entities, observations, events, edges, and meme evolution records. A graph database mirrors selected nodes and edges for traversal-heavy universe map queries.

## Major Boundaries

### Ingestion

Normalizes external content into ingestion manifests. A manifest describes the source, content item, and extracted text segments. The first implementation persists manifests through `StreamGenome.Ingestion.Workers.IngestManifestWorker`.

### Narrative Ledger

The `StreamGenome.Narrative` context owns durable lore memory:

- `creator_sources`
- `content_items`
- `content_segments`
- `narrative_entities`
- `entity_aliases`
- `entity_observations`
- `narrative_events`
- `narrative_edges`
- `meme_evolutions`

### Intelligence

Workers transform raw text into structured narrative evidence. Model providers are behind `StreamGenome.AI.Provider`, with initial adapters for Ollama and OpenAI-compatible chat completions.

### Graph Sync

`StreamGenome.Graph` is the boundary between the relational ledger and Neo4j or Memgraph. The current logging adapter keeps the application runnable before a graph database is selected.

### UI

Phoenix and LiveView will expose:

- Universe map
- Meme family trees
- Lore replay
- Emotional heatmap
- Natural-language lore search

## Data Flow

1. Fetch media, chat, comments, or export files.
2. Normalize extracted data into an ingestion manifest.
3. Persist source, content item, and content segments.
4. Queue segment-level intelligence jobs.
5. Extract entities, aliases, relationships, sentiment, callbacks, and events.
6. Persist observations and narrative edges.
7. Sync graph-compatible records to Neo4j or Memgraph.
8. Serve search, replay, and visualization queries.

## Design Principles

- Keep evidence traceable back to source content and timestamps.
- Treat AI output as proposed structure, not unquestioned truth.
- Prefer append-friendly lore records over destructive rewriting.
- Preserve chronology so memes and arcs can die, revive, mutate, and branch.
- Keep graph storage replaceable until traversal requirements become concrete.
