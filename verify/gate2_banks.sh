#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "$HERE/lib.sh"
for b in personal-alice team-eng; do
  c=$(rest_code PUT "$HC_DEMO_TOKEN_ALICE" "$(hc_bank_path "$b")" "{\"name\":\"$b\"}")
  case "$c" in 200|201) ;; *) hc_log "create $b -> $c"; exit 1;; esac
done
# confirm provisioned: recall on the bank responds 200 (empty bank returns {"results":[]})
for b in personal-alice team-eng; do
  g=$(rest_code POST "$HC_DEMO_TOKEN_ALICE" "$(hc_bank_path "$b")/memories/recall" '{"query":"_provision_check_"}')
  [ "$g" = "200" ] || { hc_log "confirm $b -> $g"; exit 1; }
done
hc_log "personal-alice + team-eng provisioned (PUT 200 + recall 200)"; exit 0
