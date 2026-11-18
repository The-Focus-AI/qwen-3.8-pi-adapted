#!/usr/bin/env bash
# Bench Q5 → Q4 → Q3 → Q8 ctl-b. One model at a time.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
EXP="$ROOT/experiments/inference"
RESTART="$EXP/scripts/restart_serve.sh"

run_one() {
  local name="$1" model="$2" cfg="$3"
  echo "######## $name ########"
  MODEL="$ROOT/$model" LOG="$EXP/logs/serve-$name.log" bash "$RESTART"
  python3 "$EXP/scripts/bench.py" run "$EXP/configs/$cfg" --reps 6 | tee "$EXP/logs/bench-$name.log"
}

run_one q5-k-m-local weights/Qwen3.8-27B-Q5_K_M.gguf q5-local.json
run_one q4-k-m-local weights/Qwen3.8-27B-Q4_K_M.gguf q4-local.json
run_one q3-k-m-local weights/Qwen3.8-27B-Q3_K_M.gguf q3-local.json
run_one baseline-q8-ctl-b weights/Qwen3.8-27B-Q8_0.gguf q8-ctl-b.json

echo "######## SWEEP DONE ########"
python3 "$EXP/scripts/bench.py" show "$EXP/ledger.jsonl"
