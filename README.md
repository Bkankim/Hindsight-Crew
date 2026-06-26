# Hindsight-Crew

Self-hosted, **agent-bootstrappable** team-memory stack on top of [Hindsight](https://github.com/vectorize-io/hindsight) — reproduced by a single unattended command, with **verifiable tenant isolation** as the headline.

> Status: **v1 in progress.** Success is defined by `verify/verify-all.sh` exiting `0`.

## What this is / when to use it

A public MIT reference package that stands up a self-hosted Hindsight memory stack with a **policy-enforcing gateway** so a team can keep per-person `personal` banks and shared `team` banks **isolated** — and prove it. Built for on-prem / no-external-cloud deployments and for dropping into client engagements in one command.

Hindsight's built-in auth is a single shared key; it has **no identity→bank enforcement**. So a thin assumption ("just point clients at 8888") leaks across tenants. Hindsight-Crew puts a **body-aware deny-by-default gateway** in front as the single enforcement point.

## Quick start (unattended)

```sh
cp .env.example .env.local   # optional; bootstrap auto-seeds demo secrets if absent
./bootstrap                  # auto-detect profile -> seed -> compose up -> verify-all -> exit code
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

> Minimum numbers are **measured** at Stage 2 by `bootstrap` (observed RAM/disk), not guessed. Placeholders below until measured.

- **Minimum — `cpu-en` profile (the only v1-fully-verified path):** any Docker host. **Measured footprint:** runtime ~0.85 GB RAM (hindsight ~811 MB + gateway ~38 MB RSS), ~7 GB disk (images ~6.8 GB + volumes ~0.37 GB), ~2 vCPU. Runs on a **2 GB** Docker VM. Note: the DR `restore-test` boots a throwaway instance, so on hosts with < ~3 GB free it stops the main stack first to avoid OOM (auto-handled).
- **Recommended — `ko-full` / `gpu` profiles _(opt-in, NOT v1-verified)_:** Korean full models (`bge-m3` ~2.3 GB + reranker) want ~8–16 GB RAM; `gpu` needs a CUDA GPU + TEI.
- **Tested on (reference, not a minimum):** macOS (Apple Silicon) via Docker Desktop with a **~2 GB** Docker VM; Hindsight `v0.8.3`, `cpu-en` offline profile (`LLM_PROVIDER=none`). All 7 `verify-all` gates GREEN.

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
profiles/  cpu-en (verified) / ko-full / gpu (opt-in)
tests/     gateway unit + adversarial + attribution (probe-generated mocks)
docs/      RUNBOOK · THREAT-MODEL · deploy-systemd
```

## License

MIT.
