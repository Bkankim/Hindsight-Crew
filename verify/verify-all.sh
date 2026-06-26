#!/usr/bin/env bash
# verify-all.sh — release gate orchestrator for Hindsight-Crew.
#
# Runs the 6 acceptance gates + the contract-drift probe and aggregates a single
# exit code. Exit 0 ONLY when every gate is PASS. Any FAIL or NOT_IMPLEMENTED → non-zero.
# This is the success definition: `./bootstrap` is "green" iff `verify-all.sh` exits 0.
#
# Gate contract (each verify/gate*.sh): exit 0=PASS, 1=FAIL, 2=NOT_IMPLEMENTED.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=verify/lib.sh
. "$HERE/lib.sh"

# Load .env.local then profile if present (non-fatal in skeleton stage).
ROOT="$(cd "$HERE/.." && pwd)"
[ -f "$ROOT/.env.local" ] && set -a && . "$ROOT/.env.local" && set +a || true

# gate id | human label
GATES=(
  "gate1_health.sh|① 8888 health (gateway front)"
  "gate2_banks.sh|② personal/team bank provisioned"
  "gate3_roundtrip.sh|③ sync_retain -> recall roundtrip"
  "gate4_isolation.sh|④ tenant isolation + team-retain attribution"
  "gate5_adversarial.sh|⑤ adversarial inputs rejected"
  "gate_contract_drift.sh|✦ contract-drift probe (live contract)"
  "gate6_restore.sh|⑥ backup restore-test"
)

declare -i fail=0 notimpl=0 pass=0
printf '\n=== Hindsight-Crew verify-all ===\n'
for entry in "${GATES[@]}"; do
  script="${entry%%|*}"; label="${entry#*|}"
  path="$HERE/$script"
  if [ ! -x "$path" ] && [ ! -f "$path" ]; then
    printf '  %-6s %s\n' "MISS" "$label (missing $script)"; notimpl+=1; continue
  fi
  bash "$path" >/tmp/hc-gate.$$ 2>&1
  rc=$?
  case $rc in
    0) printf '  %-6s %s\n' "GREEN" "$label"; pass+=1 ;;
    2) printf '  %-6s %s\n' "TODO" "$label"; notimpl+=1 ;;
    *) printf '  %-6s %s\n' "RED" "$label"; fail+=1
       sed 's/^/        /' /tmp/hc-gate.$$ | tail -6 ;;
  esac
done
rm -f /tmp/hc-gate.$$

total=${#GATES[@]}
printf '\n  summary: %d GREEN / %d RED / %d TODO  (of %d)\n' "$pass" "$fail" "$notimpl" "$total"
if [ "$pass" -eq "$total" ]; then
  printf '  RESULT: GREEN (exit 0)\n\n'; exit 0
fi
printf '  RESULT: NOT GREEN (exit 1)\n\n'; exit 1
