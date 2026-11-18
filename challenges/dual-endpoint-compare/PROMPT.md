Build a Bun CLI that sends the **same** prompt to two OpenAI-compatible base URLs and prints the replies side by side with wall-clock latency for each.

Defaults:

- Left: `http://127.0.0.1:9931/v1` model `qwen3.8-pi` key `dummy`
- Right: override via env `RIGHT_BASE_URL` / `RIGHT_MODEL` / `RIGHT_API_KEY` (if unset, call the left endpoint twice with different temperatures 0 vs 1 so the tool still demos)

Verify with one short prompt.
