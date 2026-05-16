# Roadmap

## Milestone 1: Lore Ledger

- Persist sources, content items, segments, entities, aliases, observations, events, edges, and meme evolution records.
- Queue ingestion and intelligence work with Oban.
- Add fixture-based ingestion tests.
- Add source evidence views for every generated lore object.

## Milestone 2: Extractors

- Implement transcript, chat, comment, and community export parsers.
- Add provider-backed entity extraction.
- Add relation extraction and callback detection.
- Store confidence, model metadata, and prompt version on generated evidence.

## Milestone 3: Graph Database

- Choose Neo4j or Memgraph as the first production adapter.
- Sync entity and edge mutations.
- Add graph traversal queries for callbacks, conflicts, meme ancestry, and long-lived arcs.

## Milestone 4: Timeline Intelligence

- Build chronology replay queries.
- Track meme lifecycle states: emerging, growing, stable, declining, dormant, revived, dead.
- Add emotional intensity rollups by time period, source, stream, and community.

## Milestone 5: Creator Universe UI

- Interactive universe map.
- Meme family tree view.
- Lore replay view.
- Emotional heatmap.
- Natural-language search over lore memory.

## Milestone 6: Advanced Narrative Features

- Documentary mode.
- Semantic clip retrieval.
- Audience faction detection.
- Meme prediction.
- Narrative collapse detection.
