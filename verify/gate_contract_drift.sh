#!/usr/bin/env bash
# gate_contract_drift.sh — Drift: live image tools/list, bank-arg behavior, attribution-accept match probe fixture
# Implemented in Stage 2. Until then returns NOT_IMPLEMENTED (2) so verify-all reports TODO/RED.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"
hc_log "Drift: live image tools/list, bank-arg behavior, attribution-accept match probe fixture — pending (Stage 2)"
exit $HC_GATE_NOTIMPL
