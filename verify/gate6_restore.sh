#!/usr/bin/env bash
# gate6_restore.sh — Gate 6: backup -> empty-stack restore -> retain/recall works
# Implemented in Stage 4. Until then returns NOT_IMPLEMENTED (2) so verify-all reports TODO/RED.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"
hc_log "Gate 6: backup -> empty-stack restore -> retain/recall works — pending (Stage 4)"
exit $HC_GATE_NOTIMPL
