Create a Bun + TypeScript CLI in this directory that streams chat completions from the local llama.cpp server:

- Base URL: `http://127.0.0.1:9931/v1`
- Model: `qwen3.8-pi`
- API key: `dummy` (send `Authorization: Bearer dummy`)

Features: interactive REPL, Ctrl-C cancels the current stream, prints TTFT and tok/s for each reply when the stream ends (from wall clock + completion tokens). Add a one-line README and verify it works with one non-interactive prompt flag if you add one.
