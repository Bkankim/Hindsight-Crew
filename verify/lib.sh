#!/usr/bin/env bash
# verify/lib.sh — shared helpers for verify-all gates.
# Sourced by gate*.sh and verify-all.sh. No side effects on source.

set -o pipefail

# Exit-code contract for gate scripts:
#   0 = PASS   1 = FAIL   2 = NOT_IMPLEMENTED (counts as RED for release, distinct in report)
HC_GATE_PASS=0
HC_GATE_FAIL=1
HC_GATE_NOTIMPL=2

hc_repo_root() {
  # repo root = parent of this verify/ dir
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

hc_log()  { printf '  %s\n' "$*" >&2; }
hc_pass() { printf 'PASS %s\n' "$*" >&2; return 0; }
hc_fail() { printf 'FAIL %s\n' "$*" >&2; return 1; }

# hc_assert <description> <test-command...> — runs command, returns 0/1.
hc_assert() {
  local desc="$1"; shift
  if "$@"; then hc_log "ok: $desc"; return 0; fi
  hc_log "MISS: $desc"; return 1
}

# hc_gateway_base — host-facing gateway URL (clients hit the gateway, never 8888 directly
# except in honest-but-curious bypass tests). Default matches .env.example HC_GATEWAY_BIND.
hc_gateway_base() { printf 'http://%s' "${HC_GATEWAY_BIND:-127.0.0.1:8888}"; }

# hc_mcp_call <token> <bank> <json-rpc-body> — POST a single JSON-RPC call through the
# gateway for <bank>, with the member token. Implemented fully in Stage 3 (needs lib SSE).
# Stage 0/1: placeholder that signals not-wired so gates report NOT_IMPLEMENTED.
hc_mcp_call() {
  hc_log "hc_mcp_call not wired until Stage 3 (agent-integration)"
  return 2
}
