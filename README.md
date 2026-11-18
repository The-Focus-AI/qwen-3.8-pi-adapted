# qwen-3.8-pi-adapted

Run [Qwen3.8-27B](https://huggingface.co/ggml-org/Qwen3.8-27B-GGUF) with the [Pi-adapted LoRA](https://huggingface.co/harness-hub/Qwen3.8-27B-pi-adapted-GGUF) on a Mac, talk to it through a project-local [π](https://pi.dev) agent, and optionally benchmark with the inference-optimisation skill.

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

More ideas:

```bash
mise run ask -- "Add examples/stream-once: one Bun script that streams a single completion from :9931, and verify that it works"

mise run ask -- "Add examples/compare: Bun CLI that sends the same prompt to two llama.cpp base URLs side by side, and verify that it works"

mise run ask -- "Create examples/openai-sdk: TypeScript using the openai package against :9931 / qwen3.8-pi, and verify that it works"

mise run ask -- "Create examples/healthcheck: script that checks /health and /v1/models on :9931 for qwen3.8-pi, and verify that it works"
```

### Quick Q&A (no file writes)

```bash
mise run pi -- --print --no-session "The capital of France?"
```

## Task cheat sheet

| Command | What it does |
|---|---|
| `mise install` / `mise run setup` | Node, llama.cpp, local pi, project `.pi` config |
| `npx skills add https://github.com/sybil-solutions/inference-optimisation-skill` | Install the optimisation skill |
| `mise run download` | Base model + LoRA into `weights/` |
| `mise run serve` | Q4 + Pi LoRA on `:9931` (auto-download if missing) |
| `QUANT=q8 mise run serve` | Q8 + LoRA instead |
| `mise run serve:raw` | llama.cpp base model only |
| `mise run serve:bonsai` | Ternary Bonsai Q2_0 (no LoRA) |
| `TYPE=all mise run quantize` | Local Q5/Q4/Q3 from Q8 |
| `mise run pi` | Interactive π (optional prompt after `--`) |
| `mise run ask -- "…"` | One-shot π with coding tools |

Stop the server with Ctrl‑C in the `serve` terminal when you are done.
