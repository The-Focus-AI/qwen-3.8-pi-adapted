Write a small Bun script `healthcheck.ts` that:

1. GETs `http://127.0.0.1:9931/health`
2. GETs `http://127.0.0.1:9931/v1/models` (Bearer `dummy` if needed)
3. Exits 0 only if both succeed and `qwen3.8-pi` appears in the model list
4. Prints a one-line JSON summary: `{ ok, models, latency_ms }`

Verify by running it.
