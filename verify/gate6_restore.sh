#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "$HERE/lib.sh"
F=$(bash "$ROOT/scripts/backup.sh" 2>/tmp/hc-bk.err) || { hc_log "backup failed: $(tail -1 /tmp/hc-bk.err)"; exit 1; }
hc_log "backup: $(tail -1 /tmp/hc-bk.err)"
bash "$ROOT/scripts/restore-test.sh" "$F" >/tmp/hc-rt.out 2>&1 && { hc_log "$(tail -1 /tmp/hc-rt.out)"; exit 0; }
hc_log "restore-test failed: $(tail -1 /tmp/hc-rt.out)"; exit 1
