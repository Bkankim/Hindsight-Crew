# RUNBOOK — Hindsight-Crew (agent-executable)

Structure: each stage is `RED (pre-check) → GREEN (action) → VERIFY (post-check)`. The whole
package is "done" when `verify/verify-all.sh` exits `0`.

## Phase 0 — prerequisites
- **RED:** `docker info` (daemon up), `docker --version`, `jq --version`, free disk ≥ 8 GB.
- **GREEN:** install missing tools.
- **VERIFY:** all present.

## Phase 1 — clone & configure
- **GREEN:** `git clone <repo> && cd Hindsight-Crew`. Optionally `cp .env.example .env.local` and pin
  `HC_HINDSIGHT_IMAGE` to a real `@sha256` digest for reproducible/non-demo use. If omitted, `bootstrap`
  seeds demo secrets and uses the floating `:latest` tag (pin a digest for production). Hindsight bundles
  an embedded Postgres (pg0) — there is no separate Postgres service to configure.
- **VERIFY:** `scripts/secret-hygiene.sh` clean.

## Phase 2 — unattended bootstrap
- **GREEN:** `./bootstrap` — detects profile (default `ko-full` Korean; `--cpu-en` light/CI fallback, `--gpu` opt-in),
  seeds upstream key + 2 demo member tokens + a team-bank ACL if `.env.local` absent,
  `docker compose up -d`, then runs `verify/verify-all.sh`.
- **VERIFY:** exit code `0`; `bootstrap` prints observed RAM/disk (feeds README Minimum).

## Phase 3 — verify (manual / CI)
- `verify/verify-all.sh` — 6 gates + drift probe, aggregated exit code.
- Individual gates: `verify/gate4_isolation.sh`, etc. (each exits 0/1/2).

## Phase 4 — backup / DR (opt-in scheduling)
- `scripts/backup.sh` (pg_dump + volume tar + 0-byte hard guard + retention).
- `scripts/restore-test.sh` (proves a backup restores into an empty stack).
- Scheduling is **opt-in** and documented in `docs/deploy-systemd.md` (cron or systemd timer) —
  intentionally not installed by `bootstrap` to stay OS-neutral.

## Phase 5 — teardown
- `scripts/teardown.sh` — stops the stack and removes volumes.

## Troubleshooting
- `8888` (gateway front) unresponsive on first boot: the embedding/reranker model is downloading;
  wait for "Application startup complete" in `docker compose logs -f hindsight`.
- Gate ④/⑤ RED: inspect the gateway audit log (token fingerprints, attempted-vs-resolved bank).
- Profile change after data exists: requires reindex (embedding dim is locked at boot-0).
