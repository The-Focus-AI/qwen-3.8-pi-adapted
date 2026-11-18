# π challenge prompts

Each folder is a self-contained coding challenge for the local stack (`mise run serve` + optional Ollama).

| Challenge | Depends on | Rough shape |
|---|---|---|
| [`labs-sqlite-search`](labs-sqlite-search/) | llama.cpp `:9931`, Ollama `embeddinggemma-2` | Bun app → fetch labs.thefocus.ai → SQLite + embeddings + search |
| [`pelican-bicycle`](pelican-bicycle/) | llama.cpp `:9931` | Animated SVG: pelican riding a bicycle |
| [`stream-chat-cli`](stream-chat-cli/) | llama.cpp `:9931` | Bun streaming chat CLI against `/v1` |
| [`health-and-models`](health-and-models/) | llama.cpp `:9931` | Tiny healthcheck for `/health` + `/v1/models` |
| [`dual-endpoint-compare`](dual-endpoint-compare/) | llama.cpp (+ optional 2nd URL) | Side-by-side completion compare |

## How timing works

π does **not** emit a built-in “challenge duration.” Measure from the outside:

1. **Wall clock** around the one-shot π run (`ask` / `challenge`).
2. **llama.cpp `/metrics` delta** before → after (prompt tokens, predicted tokens, GPU seconds → tok/s).
3. Optional **session JSONL** timestamps under `.pi/agent/sessions/` (first → last event).

```bash
# one challenge, timed + metrics snapshot
mise run challenge -- labs-sqlite-search

# or raw wall clock
time mise run ask -- "$(cat challenges/labs-sqlite-search/PROMPT.md)"
```

Results append to `logs/challenges.jsonl`.
