# Examples

## `chat` — interactive streaming CLI (Bun/TypeScript)

A REPL that streams tokens from a llama.cpp OpenAI-compatible server
(default `http://127.0.0.1:9931/v1`, model `qwen3.8-pi`).

```bash
cd examples/chat
bun install
bun run            # or: LLAMA_API_KEY=... bun run
```

Config via env: `LLAMA_BASE_URL`, `LLAMA_MODEL`, `LLAMA_API_KEY`.

### What I learned building it

- **The server enforces an API key.** Every request needs
  `Authorization: Bearer $LLAMA_API_KEY` or you get a `401`. Always send it.
- **Stream = SSE, not NDJSON.** Responses are `data: {...}` lines separated by
  blank lines (`\n\n`), ending with `data: [DONE]`. Buffer until you see the
  blank-line separator, then parse each `data:` payload's
  `choices[0].delta.content`. Don't assume one JSON object per line.
- **`delta.content` can be `null`** (first chunk carries only `role`). Skip
  nulls; only non-null strings are actual tokens.
- **Don't use `readline.question()` for a streaming REPL.** With `terminal:true`
  it throws `ERR_USE_AFTER_CLOSE` on EOF and swallows buffered lines when input
  is piped. Instead, consume stdin via an async line reader (queue + waiters,
  resolve on `line`, `null` on `close`) — it behaves the same for TTY and pipes.
- **Store the *real* assistant text in history.** If you push `content: ""` for
  the assistant turn, follow-up questions lose all context and the model can't
  answer them.
- **llama.cpp sends a `timings` field** in the final chunk (prefill/decode tok/s,
  cache hits). Handy for benchmarking but not part of the OpenAI spec — ignore
  it when parsing.
- **`model` is a free-form string** with llama.cpp; `"default"` works fine.
