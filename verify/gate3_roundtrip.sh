#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "$HERE/lib.sh"
MARK="rt-$$-$RANDOM"
rest_code POST "$HC_DEMO_TOKEN_ALICE" "$(hc_bank_path personal-alice)/memories" \
  "{\"items\":[{\"content\":\"verify roundtrip marker $MARK regarding quarterly budget\"}]}" >/dev/null
sleep 3
body=$(rest_body POST "$HC_DEMO_TOKEN_ALICE" "$(hc_bank_path personal-alice)/memories/recall" \
  '{"query":"quarterly budget roundtrip marker"}')
echo "$body" | grep -q "$MARK" && { hc_log "sync_retain->recall round-trip ok"; exit 0; }
hc_log "recall missing marker: $(echo "$body" | head -c 160)"; exit 1
