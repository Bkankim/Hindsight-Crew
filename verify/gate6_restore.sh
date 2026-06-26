#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "$HERE/lib.sh"
A="$HC_DEMO_TOKEN_ALICE"
# Seed a UNIQUE DR marker into team-eng on the main stack, so the restore assertion checks data
# we KNOW is in the backup — deterministic and model-independent (not whatever other gates left).
MARK="restore-marker-$$-$RANDOM"
CONTENT="restore drill marker $MARK"
rest_code POST "$A" "$(hc_bank_path team-eng)/memories" \
  "{\"items\":[{\"content\":\"$CONTENT\"}]}" >/dev/null
# Wait until it is actually recallable on main (=> persisted to pg0) BEFORE taking the backup.
seeded=0
for i in $(seq 1 12); do
  b=$(rest_body POST "$A" "$(hc_bank_path team-eng)/memories/recall" "{\"query\":\"$CONTENT\"}")
  echo "$b" | grep -q "$MARK" && { seeded=1; break; }
  sleep 2
done
[ "$seeded" = 1 ] || { hc_log "restore: DR marker not persisted on main before backup"; exit 1; }
F=$(bash "$ROOT/scripts/backup.sh" 2>/tmp/hc-bk.err) || { hc_log "backup failed: $(tail -1 /tmp/hc-bk.err)"; exit 1; }
hc_log "backup: $(tail -1 /tmp/hc-bk.err)"
HC_RESTORE_MARKER="$CONTENT" bash "$ROOT/scripts/restore-test.sh" "$F" >/tmp/hc-rt.out 2>&1 && { hc_log "$(tail -1 /tmp/hc-rt.out)"; exit 0; }
hc_log "restore-test failed: $(tail -1 /tmp/hc-rt.out)"; exit 1
