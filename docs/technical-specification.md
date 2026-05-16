# Stream.Genome Technical Specification

## Goal

Build an open-source AI-powered creator universe engine.

The platform ingests creator content, detects recurring entities, builds persistent lore memory, tracks meme evolution, connects events across years of content, generates narrative relationships, and exposes searchable creator universe maps.

The system is not a chatbot. It is a persistent narrative intelligence engine.

## Core Concept

Stream.Genome continuously builds an evolving world model of a creator ecosystem.

It models people, memes, phrases, conflicts, arcs, communities, emotional relationships, recurring themes, and audience reactions across long periods of content.

## Supported Inputs

Media:

- YouTube videos
- Twitch VODs
- Kick streams
- Podcasts
- TikTok clips

Community sources:

- Discord exports
- Telegram exports
- Reddit threads
- YouTube comments
- Twitch chat logs

## Pipeline

### Stage 1: Ingestion

- Media download
- Transcription
- OCR
- Chat parsing
- Metadata extraction

### Stage 2: Entity Detection

- People
- Nicknames and aliases
- Memes
- Repeated phrases
- Running jokes
- Topics
- Recurring conflicts
- Persistent entity IDs

### Stage 3: Narrative Correlation

- Meme origins
- Meme evolution
- Recurring events
- Callbacks
- Emotional spikes
- Audience reactions
- Narrative graph construction

## Narrative Graph

Node types:

- Person
- Meme
- Event
- Phrase
- Community
- Stream
- Conflict
- Arc

Edge types:

- references
- evolved_into
- originated_from
- emotionally_linked
- triggered
- repeated_by
- associated_with

## Temporal Intelligence

The system preserves chronology, seasonal changes, meme death and revival, and community shifts.

It must support timeline replay across selected historical windows.

## UI

- Universe Map: interactive graph of entities, memes, events, and arcs.
- Meme Trees: visual meme evolution and family relationships.
- Lore Replay: historical state replay over time.
- Emotional Heatmap: emotional intensity over a timeline.

## Search

The search layer supports natural-language questions such as:

- When did meme X start?
- Show all conflicts involving Y.
- Most repeated phrase in 2024.
- Which meme survived the longest?

## AI Layer

Supported providers:

- Ollama
- OpenAI-compatible APIs
- Local models

Tasks:

- Summarization
- Entity extraction
- Relation extraction
- Lore generation
- Callback detection

## Non-Goals

Stream.Genome must not become:

- A recommendation algorithm
- An ad platform
- Surveillance tooling
- A manipulative engagement system
