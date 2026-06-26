#!/usr/bin/env bash
# gate4_isolation.sh — Gate 4: cross-tenant denied + team-retain attribution (round-trip)
# Implemented in Stage 3. Until then returns NOT_IMPLEMENTED (2) so verify-all reports TODO/RED.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"
hc_log "Gate 4: cross-tenant denied + team-retain attribution (round-trip) — pending (Stage 3)"
exit $HC_GATE_NOTIMPL
