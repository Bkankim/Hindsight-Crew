#!/usr/bin/env bash
# verify/lib.sh — shared helpers. Gates run on the HOST and hit the published gateway
# (the single front door); they NEVER touch hindsight 8888 directly. bash 3.2 compatible.
set -o pipefail
HC_GATE_PASS=0; HC_GATE_FAIL=1; HC_GATE_NOTIMPL=2

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$ROOT/.env.local" ]            && { set -a; . "$ROOT/.env.local"; set +a; }
[ -f "$ROOT/secrets/demo-tokens.env" ] && { set -a; . "$ROOT/secrets/demo-tokens.env"; set +a; }
HC_GW="http://${HC_GATEWAY_BIND:-127.0.0.1:8888}"
HC_TENANT="${HC_TENANT:-default}"

hc_log() { printf '    %s\n' "$*" >&2; }

# rest_code METHOD TOKEN PATH [BODY]  -> prints HTTP status code
rest_code() {
  local m="$1" t="$2" p="$3" b="${4:-}"
  local a=(-s -o /dev/null -w '%{http_code}' --max-time 25 -X "$m" "$HC_GW$p" -H 'content-type: application/json')
  [ -n "$t" ] && a+=(-H "authorization: Bearer $t")
  [ -n "$b" ] && a+=(-d "$b")
  curl "${a[@]}"
}
# rest_body METHOD TOKEN PATH [BODY]  -> prints response body
rest_body() {
  local m="$1" t="$2" p="$3" b="${4:-}"
  local a=(-s --max-time 25 -X "$m" "$HC_GW$p" -H 'content-type: application/json')
  [ -n "$t" ] && a+=(-H "authorization: Bearer $t")
  [ -n "$b" ] && a+=(-d "$b")
  curl "${a[@]}"
}
hc_bank_path() { printf '/v1/%s/banks/%s' "$HC_TENANT" "$1"; }
