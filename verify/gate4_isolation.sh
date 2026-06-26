#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "$HERE/lib.sh"
A="$HC_DEMO_TOKEN_ALICE"
c=$(rest_code POST "$A" "$(hc_bank_path personal-bob)/memories/recall" '{"query":"x"}')
[ "$c" = "403" ] || { hc_log "cross-tenant alice->bob expected 403 got $c"; exit 1; }
c=$(rest_code POST "$A" "$(hc_bank_path personal-alice)/memories/recall" '{"query":"x"}')
[ "$c" = "200" ] || { hc_log "own bank expected 200 got $c"; exit 1; }
# team-retain attribution round-trip: gateway stamps hc_member=alice and it must persist+recall
M="attr-$$-$RANDOM"
rest_code POST "$A" "$(hc_bank_path team-eng)/memories" \
  "{\"items\":[{\"content\":\"attribution probe $M\",\"metadata\":{\"hc_member\":\"bob\"}}]}" >/dev/null   # forge bob
sleep 3
body=$(rest_body POST "$A" "$(hc_bank_path team-eng)/memories/recall" "{\"query\":\"attribution probe $M\"}")
echo "$body" | grep -q "$M" || { hc_log "attribution probe not recalled"; exit 1; }
echo "$body" | grep -q '"hc_member":"alice"' || { hc_log "attribution NOT alice (forgery not overwritten): $(echo "$body"|head -c 160)"; exit 1; }
echo "$body" | grep -q '"hc_member":"bob"' && { hc_log "forged bob attribution leaked!"; exit 1; }
hc_log "isolation + team-retain attribution (forgery overwritten, round-trip) ok"; exit 0
