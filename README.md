# Hindsight-Crew

Self-hosted, **agent-bootstrappable** team-memory stack on top of [Hindsight](https://github.com/vectorize-io/hindsight) — reproduced by a single unattended command, with **verifiable tenant isolation** as the headline.

> Status: **v1 in progress.** Success is defined by `verify/verify-all.sh` exiting `0`.

## What this is / when to use it

A public MIT reference package that stands up a self-hosted Hindsight memory stack with a **policy-enforcing gateway** so a team can keep per-person `personal` banks and shared `team` banks **isolated** — and prove it. Built for on-prem / no-external-cloud deployments and for dropping into client engagements in one command.

Hindsight's built-in auth is a single shared key; it has **no identity→bank enforcement**. So a thin assumption ("just point clients at 8888") leaks across tenants. Hindsight-Crew puts a **body-aware deny-by-default gateway** in front as the single enforcement point.

## Quick start (unattended)

```sh
cp .env.example .env.local   # optional; bootstrap auto-seeds demo secrets if absent
./bootstrap                  # default ko-full (Korean, needs ~4GB+); or ./bootstrap --cpu-en (light/2GB/CI)
```

`./bootstrap` is green **iff** `verify/verify-all.sh` exits `0` (6 gates + drift probe).

## Acceptance gates (`verify/verify-all.sh`)

| Gate | Proves |
|---|---|
| ① health | gateway front returns 200 |
| ② banks | personal + team bank provisioned |
| ③ roundtrip | `sync_retain` → `recall` returns the memory |
| ④ isolation + attribution | A-token cannot read B's bank; team-retain is attributed to the member (round-trip verified) |
| ⑤ adversarial | unknown/ACL-less token, path traversal, `X-Bank-Id` + **body `arguments.bank`** smuggling, attribution forgery all rejected |
| ⑥ restore | backup → empty-stack restore → retain/recall works |

## System Requirements

> Minimum numbers below are **measured** on the live stack by `bootstrap` / `verify-all` (observed RAM/disk), not guessed.

- **Default — `ko-full` profile (Korean, RECOMMENDED for the target use case):** `BAAI/bge-m3` (1024-dim) + `BAAI/bge-reranker-v2-m3` (official multilingual 568M; `dragonkue/bge-reranker-v2-m3-ko` is an optional Korean-tuned hot-swap — rerankers are **not** dimension-locked, swap anytime). Offline `LLM=none`. **Measured:** runtime ~1.5–2.1 GB RAM (hindsight) + ~59 MB (gateway), ~14 GB disk (images ~6.8 GB + volumes ~7.2 GB incl. Korean models ~5 GB); needs **~4 GB+ RAM**. **Pick this at boot-0** — the embedding model IS the vector dimension, so switching profiles after data is loaded forces a full reindex/wipe.
- **Lightweight fallback — `cpu-en` (`./bootstrap --cpu-en`):** English `bge-small-en-v1.5` + `ms-marco-MiniLM` (~217 MB). **Measured:** runtime ~0.85 GB RAM, ~7 GB disk, runs on a **2 GB** Docker VM; this is the **CI-verified** profile (verify-all 7/7 GREEN). Use for CI / constrained hosts / English corpora.
- **`gpu` profile _(opt-in)_:** Korean models via TEI; needs a CUDA GPU.
- **Tested on (reference):** **`ko-full`** live-verified — `verify-all` **7/7 GREEN** on Colima (Apple Silicon, 6 vCPU / 10 GiB), Hindsight `v0.8.3`, `bge-m3` (1024-dim) + `bge-reranker-v2-m3`, fully offline (`LLM=none`); Korean semantic recall confirmed (lexically-different KO queries resolved to the right memory). **`cpu-en`** verified on a **2 GB** VM (the lightweight CI profile).

## Threat model

Honest-but-curious (stops accidental cross-bank access by colleagues). Active/malicious bypass (e.g. hitting `8888` directly on the host) is **out of v1 scope** — see [`docs/THREAT-MODEL.md`](docs/THREAT-MODEL.md) for residual risks and the upgrade path (mTLS / per-bank keys / rate-limiting).

## Pinning & reproducibility

Images are pinned by **digest (`@sha256`)**, not tag — Hindsight v0.x moves fast. Embedding profile is locked at boot-0 (changing the embedding model changes the vector dimension → requires reindex).

## Not in v1 (phase 2)

auto-capture rules · daily-report · Korean/GPU auto-verification · offsite backup · mTLS / per-bank keys / rate-limiting.

## Layout

```
gateway/   body-aware deny-by-default MCP policy gateway (app/policy/acl/audit)
verify/    verify-all.sh + gate1..6 + contract-drift + lib
scripts/   bootstrap helpers: contract-probe, seed-demo, backup, restore-test, secret-hygiene
profiles/  ko-full (default, Korean) / cpu-en (CI-verified light fallback) / gpu (opt-in)
tests/     gateway unit + adversarial + attribution (probe-generated mocks)
docs/      RUNBOOK · THREAT-MODEL · deploy-systemd
```

## License

MIT.
