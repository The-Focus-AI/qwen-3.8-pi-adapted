# qwen-3.8-pi-adapted

Run [Qwen3.8-27B](https://huggingface.co/ggml-org/Qwen3.8-27B-GGUF) with the [Pi-adapted LoRA](https://huggingface.co/harness-hub/Qwen3.8-27B-pi-adapted-GGUF) on a Mac, talk to it through a project-local [π](https://pi.dev) agent, and optionally benchmark with the inference-optimisation skill.

Everything below is meant to be run from this repo root.

## 1. Prerequisites

Install these once on the machine:

- [mise](https://mise.jdx.dev/)
- [Homebrew](https://brew.sh/)
- Hugging Face CLI (`hf`), e.g. `pip install -U huggingface_hub`

You need enough disk for ~27 GB of weights under `weights/`, and enough RAM/GPU for a 27B Q8 model plus LoRA.

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

## 4. Download the weights

```bash
mise run download
```

Files land in `weights/` (gitignored):

| File | Source |
|---|---|
| `Qwen3.8-27B-Q8_0.gguf` | `ggml-org/Qwen3.8-27B-GGUF` |
| `Qwen3.8-27B-pi-lora-F16.gguf` | `harness-hub/Qwen3.8-27B-pi-adapted-GGUF` |

Or pull them separately:

```bash
mise run download:model
mise run download:adapter
```

If a download fails with “revision not found”, list the repo and adjust:

```bash
hf repo ls harness-hub/Qwen3.8-27B-pi-adapted-GGUF
```

## 5. Start the server

In one terminal:

```bash
mise run serve
```

This starts `llama-server` with the base GGUF + LoRA, reasoning off, 32k context, port **9931**, alias **qwen3.8-pi**.

Leave it running. For the base model without LoRA:

```bash
mise run serve:raw
```

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
| `mise run serve` | llama.cpp with Pi LoRA on `:9931` |
| `mise run serve:raw` | llama.cpp base model only |
| `mise run pi` | Interactive π (optional prompt after `--`) |
| `mise run ask -- "…"` | One-shot π with coding tools |

Stop the server with Ctrl‑C in the `serve` terminal when you are done.
