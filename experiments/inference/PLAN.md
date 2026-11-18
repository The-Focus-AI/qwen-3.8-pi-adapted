# Inference optimisation — Qwen3.8-27B + Pi LoRA on M4 Max

## Targets & constraints

| Item | Value |
|---|---|
| Primary | **c1 decode tok/s** (π agent) |
| Quality | labelled lossy weight quant OK |
| Context | 131072 · LoRA on · reasoning off |
| Engine | llama-server 1.0.0 (b1b770d90) · Metal · M4 Max 64GB |

## Results table (harness median of 6, thinking off, LoRA on)

| Config | c1 tok/s | vs Q8 ctl-b | TTFT ms | Prefill 4K / 32K | Verdict |
|---|---:|---:|---:|---|---|
| Q8 ctl-a | 13.8 | — | 241 | 172 / 161 | control |
| **Q5_K_M local** | 15.18 | +5% | 234 | 144 / 150 | reject — slower than Q4 |
| **Q4_K_M local** | **19.45** | **+34%** | **209** | **191 / 172** | **ACCEPT** |
| **Q3_K_M local** | 15.59 | +8% | 219 | 186 / 166 | reject — slower than Q4 (dequant) |
| Q8 ctl-b | 14.48 | — | 225 | 197 / 180 | control |

Practical ceiling @ ~395 GB/s effective: Q4 ≈ 25 tok/s → **19.45 is ~78% of Q4 ceiling**.

## Decision (2026-11-17)

**Ship Q4_K_M** as default (`QUANT=q4` / `mise run serve`).

- Built locally: `llama-quantize --allow-requantize --leave-output-tensor` from Q8_0 (not from F16 — slight extra quality loss vs Hub Q4; throughput is what we optimized).
- Baked into `mise/tasks/serve/_default` and `download/model` default QUANT=q4.
- Q3/Q5 kept on disk for re-checks; not defaults.
- **Bonsai** still optional later (`download:bonsai` / `serve:bonsai`) — no Pi LoRA, ~7.6GB, ~72 tok/s ceiling.

## Experiment log

| Time | Config | c1 | Verdict | Reason |
|---|---|---:|---|---|
| 22:39 | baseline-q8-ctl-a | 13.8 | control | |
| 22:55 | q5-k-m-local | 15.18 | reject | beats Q8 but loses to Q4 |
| 23:01 | q4-k-m-local | **19.45** | **accept** | best c1; clean flags |
| 23:07 | q3-k-m-local | 15.59 | reject | expected bandwidth win failed — Metal Q3 cost |
| 23:13 | baseline-q8-ctl-b | 14.48 | control | Q4 still +34% vs this control |

## Next levers (after plateau on quant)

1. flash-attn / ubatch on Q4
2. KV cache dtype (labelled)
3. Bonsai Q2_0 no-LoRA A/B if π quality without adapter is OK
