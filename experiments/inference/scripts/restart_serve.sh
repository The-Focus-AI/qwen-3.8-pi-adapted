#!/usr/bin/env bash
# Drain/stop llama-server and start with MODEL=... (LoRA on unless NO_LORA=1).
set -euo pipefail
cd "$(dirname "$0")/../../.."
MODEL="${MODEL:?set MODEL=weights/...gguf}"
PORT="${PORT:-9931}"
ALIAS="${ALIAS:-qwen3.8-pi}"
# Prefer explicit CONTEXT, else mise.local.toml, else 32768
if [[ -z "${CONTEXT:-}" ]] && [[ -f mise.local.toml ]]; then
  CONTEXT=$(sed -nE 's/^CONTEXT[[:space:]]*=[[:space:]]*"?([0-9]+)"?.*/\1/p' mise.local.toml | head -1)
fi
CONTEXT="${CONTEXT:-32768}"
LOG="${LOG:-experiments/inference/logs/serve-current.log}"

# Soft stop by PID (never pkill -f)
pids=$(pgrep -x llama-server || true)
if [[ -n "$pids" ]]; then
  echo "Stopping llama-server PIDs: $pids"
  kill $pids 2>/dev/null || true
  for i in $(seq 1 60); do
    pgrep -x llama-server >/dev/null || break
    sleep 1
  done
  if pgrep -x llama-server >/dev/null; then
    echo "Force kill after drain wait"
    kill -9 $(pgrep -x llama-server) 2>/dev/null || true
    sleep 1
  fi
fi

args=(-m "$MODEL" --reasoning off -c "$CONTEXT" --port "$PORT" --alias "$ALIAS")
if [[ "${NO_LORA:-0}" != "1" ]]; then
  ADAPTER="${ADAPTER:-}"
  if [[ -z "$ADAPTER" ]]; then
    ADAPTER=$(ls weights/*lora*.gguf weights/*adapter*.gguf 2>/dev/null | head -n 1 || true)
  fi
  [[ -n "$ADAPTER" ]] || { echo "No LoRA found"; exit 1; }
  args+=(--lora "$ADAPTER")
  echo "LoRA: $ADAPTER"
fi

echo "Model: $MODEL  ctx=$CONTEXT port=$PORT"
nohup llama-server "${args[@]}" >"$LOG" 2>&1 &
echo "started pid $!"
for i in $(seq 1 300); do
  if curl -sf -H 'Authorization: Bearer dummy' "http://127.0.0.1:${PORT}/v1/models" >/dev/null 2>&1; then
    echo "HEALTHY after ${i}s"
    exit 0
  fi
  if ! pgrep -x llama-server >/dev/null; then
    echo "FAILED"; tail -30 "$LOG"; exit 1
  fi
  sleep 2
done
echo "TIMEOUT"; tail -40 "$LOG"; exit 1
