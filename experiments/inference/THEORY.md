# Theoretical ceilings — Qwen3.8-27B Q8 on M4 Max (40-GPU)

## Hardware

| Source | Bandwidth | Notes |
|---|---:|---|
| Apple spec (M4 Max 16c/40g) | **546 GB/s** | LPDDR5X unified |
| Measured device-copy | TBD | no standalone Metal copy bench yet; will back out from decode |

Peak FP16 GEMM: TBD (prefill secondary). Practical prefill uses ~50% of measured peak.

## Model (from GGUF)

- Arch: `qwen35` hybrid (SSM/GDN + attention), name Qwen3.8-27B
- Layers: 64 · emb: 5120 · FFN: 17408 · heads: 24 · KV heads: 4 · head_dim: 256
- SSM: conv_k=4, state=128, groups=16, dt_rank=48, inner=6144
- Quant: Q8_0 file ≈ **27.0 GB** + LoRA F16 ≈ **0.30 GB**
- MoE: none observed in early metadata (treat as dense weight traffic per token)

## Decode (memory-bound)

Bytes/token ≈ full weights ≈ **27.3 GB** (base + LoRA) at short context; KV grows with depth but is secondary vs weights on a 27B Q8.

| Quant | Weight GB (HF) | Spec c1 ceiling (546 / GB) | Measured c1 |
|---|---:|---:|---:|
| Q8_0 + LoRA (baseline) | ~28.6 | **≈ 19.1** | **13.8** (72%) |
| **Q4_K_M + LoRA** | **19.4** | **≈ 28.1** | TBD |
| Bonsai 2 Q2_0 (no LoRA) | **7.6** | **≈ 71.8** | TBD |
| BF16 | 53.8 | ≈ 10.1 | ignore |

Effective BW from Q8: 13.8 × ~28.6 ≈ **395 GB/s** (~72% of 546). At that effective BW: Q4 ≈ **20.4**, Bonsai ≈ **52** tok/s expected if kernels keep pace.

Speculative decoding (mtp/dflash) often **loses** on Apple. Park until after quant A/B.

## Prefill (compute-bound)

Active params ≈ 27B → ~54e9 FLOPs/token linear, plus attention on full-attn layers only.
Ceilings filled after a Metal GEMM or from measured prefill vs FLOPs estimate.

## KV / concurrency

- Hybrid: **state slots**, not only KV tokens, can cap concurrency.
- Target workload: **c1** (π agent). Size context pool for 131072 × 1 with ≥12 GiB free.

## Progress rule

Report c1 decode as % of the **20 tok/s** practical-spec ceiling until measured BW replaces it.
