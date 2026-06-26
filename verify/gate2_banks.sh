#!/usr/bin/env bash
# gate2_banks.sh — Gate 2: personal + team bank provisioned
# Implemented in Stage 2. Until then returns NOT_IMPLEMENTED (2) so verify-all reports TODO/RED.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"
hc_log "Gate 2: personal + team bank provisioned — pending (Stage 2)"
exit $HC_GATE_NOTIMPL
