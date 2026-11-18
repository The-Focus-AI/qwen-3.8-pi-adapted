Build a Bun + TypeScript app in this working directory that:

1. Downloads / crawls the latest public content from https://labs.thefocus.ai (posts, titles, URLs, body text — prefer any published Markdown/raw endpoints if you find them; otherwise parse the site HTML carefully).
2. Stores documents in a local **SQLite** database (better-sqlite3 or bun:sqlite).
3. Creates **embeddings** with Ollama model `embeddinggemma-2` (or `embeddinggemma-2:latest`) at `http://127.0.0.1:11434`.
4. Uses the local llama.cpp OpenAI-compatible server at `http://127.0.0.1:9931/v1` (model `qwen3.8-pi`, API key `dummy`) to summarize / answer questions over retrieved chunks.
5. Exposes a CLI (and optionally a tiny search REPL) that can:
   - `ingest` — fetch + embed + upsert
   - `search <query>` — embedding similarity search, then optional LLM answer grounded in hits

Verify end-to-end: ingest at least a few docs, run one search, print top hits. Document how to run it in a short README.md here.
