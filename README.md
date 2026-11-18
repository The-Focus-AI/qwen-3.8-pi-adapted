# qwen-3.8-pi-adapted

Run [Qwen3.8-27B](https://huggingface.co/ggml-org/Qwen3.8-27B-GGUF) with the [Pi-adapted LoRA](https://huggingface.co/harness-hub/Qwen3.8-27B-pi-adapted-GGUF) on a Mac, talk to it through a project-local [π](https://pi.dev) agent, and optionally benchmark with the inference-optimisation skill.

> Introducing Qwen3.8-27B-pi-adapted 🤗
>
> We adapted Qwen's model specifically for the pi coding agent using reinforcement learning and a LoRA adapter.
>
> The results, measured as pass@1:
> - SWE-bench Pro (Hard 51): 29.4% → 62.7%
> - Terminal-Bench 2.1: 39.5% → 55.8%
> - 55–62% fewer tool calls per task
>
> This is the power of open models: you can adapt them to YOUR tools and YOUR use cases. Let’s build! 💛
>
> — [clem 🤗 (@ClementDelangue)](https://x.com/ClementDelangue/status/2122784279604383914)

[![Qwen3.8-27B-pi-adapted announcement](https://pbs.twimg.com/media/HXWkpZZXYAARbeP.jpg)](https://x.com/ClementDelangue/status/2122784279604383914)

Open weights: [harness-hub/Qwen3.8-27B-pi-adapted](https://huggingface.co/harness-hub/Qwen3.8-27B-pi-adapted) · Methodology: [Harness adapters](https://huggingface.co/blog/harness-hub/harness-adapters)

Everything below is meant to be run from this repo root.

## 1. Prerequisites

Install these once on the machine:

- [mise](https://mise.jdx.dev/)
- [Homebrew](https://brew.sh/)
- Hugging Face CLI (`hf`), e.g. `pip install -U huggingface_hub`

You need enough disk for weights under `weights/` (default **Q4_K_M** ~16 GB, or Q8 ~27 GB), and enough RAM/GPU for the chosen quant plus LoRA.

## 2. Bootstrap the project

```bash
mise install
```

That installs Node via mise, then runs `setup`, which:

- `brew install llama.cpp` if `llama-server` is missing
- sizes `CONTEXT` from this Mac’s unified memory (and weight file size) into `mise.local.toml`
- installs `@earendil-works/pi-coding-agent` locally (no global npm install)
- writes project-local pi config under `.pi/`
- installs **project-local** π packages from `.pi/settings.json` (rehydrates gitignored payloads under `.pi/git/` and `.pi/npm/`):
  - `git:github.com/huggingface/pi-llama`
  - `npm:pi-lens` (LSP/linter feedback on edits — local only, not global)
  - `git:github.com/badlogic/pi-subagent`

You can re-run setup any time with `mise run setup`. Pin context with `CONTEXT_OVERRIDE=65536 mise run setup`.


## 3. Add the inference-optimisation skill

```bash
npx skills add https://github.com/sybil-solutions/inference-optimisation-skill
```

This installs the skill into the project (see `.agents/skills/` / `.claude/skills/` and `skills-lock.json`). Use it from your agent when you want to bench or hill-climb inference settings against the local server.

## 4. Download the weights (optional)

`mise run serve` will download the default model + LoRA if they are missing. To prefetch explicitly:

```bash
mise run download
```

Files land in `weights/` (gitignored):

| File | Source |
|---|---|
| `Qwen3.8-27B-Q4_K_M.gguf` (default) | Hub, or `TYPE=q4 mise run quantize` from Q8 |
| `Qwen3.8-27B-Q8_0.gguf` | `QUANT=q8 mise run download:model` |
| `Qwen3.8-27B-pi-lora-F16.gguf` | `harness-hub/Qwen3.8-27B-pi-adapted-GGUF` |

Or pull them separately:

```bash
mise run download:model          # default QUANT=q4
QUANT=q8 mise run download:model
mise run download:adapter
TYPE=all mise run quantize       # local Q5/Q4/Q3 from Q8
```

If a download fails with “revision not found”, list the repo and adjust:

```bash
hf repo ls harness-hub/Qwen3.8-27B-pi-adapted-GGUF
```

## 5. Start the server

In one terminal (after `mise install`):

```bash
mise run serve
```

On a fresh clone this downloads **Q4_K_M** + Pi LoRA if needed, then starts `llama-server` (reasoning off, port **9931**, alias **qwen3.8-pi**, context from `mise.local.toml`). Override with `QUANT=q8 mise run serve` or `MODEL=weights/...`.

Serve also enables Prometheus **`/metrics`**, **`/slots`**, and writes `logs/llama-server.log`. Snapshot cumulative tok/s and slot load with:

```bash
mise run stats
mise run stats:watch   # INTERVAL=5 for faster polling
```

Live Grafana demo (Docker, **no Compose** — stays in the foreground; Ctrl-C removes containers):

```bash
# terminal A
mise run serve
# terminal B
mise run demo:grafana   # → http://127.0.0.1:3000  (admin/admin)
```

Leave it running. Alternatives:

```bash
mise run serve:raw      # same quant default, no LoRA
mise run serve:bonsai   # Ternary-Bonsai Q2_0 (downloads if missing; no LoRA)
```

### Throughput (M4 Max 64 GB, local benches)

Hill-climb on this machine (c1 decode, median of 6, LoRA on, reasoning off):

| Quant | c1 tok/s | Notes |
|---|---:|---|
| Q8_0 | ~14 | previous default |
| Q5_K_M (local requant) | ~15 | slower than Q4 |
| **Q4_K_M (default)** | **~19.5** | **+34% vs Q8** — shipped default |
| Q3_K_M (local requant) | ~16 | slower than Q4 on Metal |

Details and experiment log: `experiments/inference/PLAN.md`.

## 6. Talk to it with π

Keep `mise run serve` running, then in another terminal:

```bash
mise run pi
```

Project-local `pi` + `.pi/agent/models.json` → `local/qwen3.8-pi` at `http://127.0.0.1:9931/v1`.

Scratch directory (prints a `mktemp -d` path, symlinks this repo’s `.pi` so local packages/plugins load, then starts π there):

```bash
mise run pi:tmp
mise run pi:tmp -- "Scaffold a tiny Bun hello world"
```


### Interactive (REPL)

Optional initial prompt after `--`:

```bash
mise run pi -- "What model are you running?"
```

### One-shot coding (`ask`)

`mise run ask` runs π once with tools so it can create files. Put the prompt after `--`:

```bash
mise run ask -- "Create examples/chat: a Bun/TypeScript CLI that streams from llama.cpp on :9931, and verify that it works"
```

### Quick Q&A (no file writes)

```bash
mise run pi -- --print --no-session "The capital of France?"
```

## 7. Challenge prompts (build + time)

π itself does **not** report “how long the task took.” Time the agent from the outside: wrap a one-shot `--print` run, take wall clock, and subtract llama.cpp Prometheus counters before/after.

| Challenge | Prompt | Needs |
|---|---|---|
| [`labs-sqlite-search`](challenges/labs-sqlite-search/) | Bun app: crawl [labs.thefocus.ai](https://labs.thefocus.ai), SQLite + search; llama `:9931` for understanding; Ollama `embeddinggemma-2` for embeddings | `serve` + `ollama pull embeddinggemma-2` |
| [`stream-chat-cli`](challenges/stream-chat-cli/) | Streaming Bun chat CLI vs `/v1` | `serve` |
| [`health-and-models`](challenges/health-and-models/) | `/health` + `/v1/models` check for `qwen3.8-pi` | `serve` |
| [`dual-endpoint-compare`](challenges/dual-endpoint-compare/) | Same prompt, two endpoints side by side | `serve` |

```bash
# terminal A
mise run serve
# optional for labs-sqlite-search
ollama pull embeddinggemma-2

# terminal B — timed run (temp workdir + .pi symlink, like pi:tmp)
mise run challenge -- labs-sqlite-search
mise run challenge -- health-and-models
```

Each run prints a summary and appends one line to `logs/challenges.jsonl`:

```json
{
  "challenge": "labs-sqlite-search",
  "wall_s": 412.3,
  "llama_prompt_tokens": 128400,
  "llama_predicted_tokens": 8200,
  "llama_prefill_tok_s": 310.2,
  "llama_decode_tok_s": 19.1,
  "exit_code": 0,
  "workdir": "/var/folders/.../pi-challenge-labs-sqlite-search.XXXX"
}
```

**What each number means**

| Field | Source | Meaning |
|---|---|---|
| `wall_s` | host clock around `pi --print` | End-to-end agent time (tools, waits, thinking) |
| `llama_*_tokens` / `*_tok_s` | Δ of `llamacpp:*_total` on `:9931/metrics` | Only inference work on the coding model (not Ollama embeddings) |
| `exit_code` | π process | 0 ≈ agent finished; still verify the app in `workdir` |

Ad-hoc prompts without a challenge folder:

```bash
time mise run ask -- "…"          # wall only
mise run stats                    # cumulative server counters anytime
```

Add a new challenge by dropping `challenges/<name>/PROMPT.md` (see [`challenges/README.md`](challenges/README.md)).

## Task cheat sheet

| Command | What it does |
|---|---|
| `mise install` / `mise run setup` | Node, llama.cpp, local pi, `.pi` config, **pi-lens** + pi-llama (local) |
| `npx skills add https://github.com/sybil-solutions/inference-optimisation-skill` | Install the optimisation skill |
| `mise run download` | Base model + LoRA into `weights/` |
| `mise run serve` | Q4 + Pi LoRA on `:9931` (auto-download if missing; `/metrics` + log) |
| `QUANT=q8 mise run serve` | Q8 + LoRA instead |
| `mise run serve:raw` | llama.cpp base model only |
| `mise run serve:bonsai` | Ternary Bonsai Q2_0 (no LoRA) |
| `mise run stats` | Snapshot `/metrics` + `/slots` → `logs/serve-stats.jsonl` |
| `mise run stats:watch` | Poll stats every 10s (`INTERVAL=5 mise run stats:watch`) |
| `mise run demo:grafana` | Foreground Prometheus+Grafana (Ctrl-C tears down) |
| `TYPE=all mise run quantize` | Local Q5/Q4/Q3 from Q8 |
| `mise run pi` | Interactive π in this repo (optional prompt after `--`) |
| `mise run pi:tmp` | `mktemp -d`, print path, run π there |
| `mise run ask -- "…"` | One-shot π with coding tools |
| `mise run challenge -- <name>` | Timed challenge → `logs/challenges.jsonl` |

Stop the server with Ctrl‑C in the `serve` terminal when you are done.
