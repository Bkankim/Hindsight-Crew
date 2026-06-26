#!/usr/bin/env bash
# gate5_adversarial.sh — Gate 5: unknown/ACL-less token, traversal, header+body bank smuggling, attribution forgery rejected
# Implemented in Stage 1/3. Until then returns NOT_IMPLEMENTED (2) so verify-all reports TODO/RED.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"
hc_log "Gate 5: unknown/ACL-less token, traversal, header+body bank smuggling, attribution forgery rejected — pending (Stage 1/3)"
exit $HC_GATE_NOTIMPL
