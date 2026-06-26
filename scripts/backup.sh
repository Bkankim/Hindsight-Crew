#!/usr/bin/env bash
# backup.sh — back up the embedded pg0 data volume with a HARD 0-byte guard (the silent
# empty-backup incident is the direct motivation) + retention. Prints the backup file path.
set -eu
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"
[ -f .env.local ] && { set -a; . ./.env.local; set +a; }
TS="$(date +%Y%m%d-%H%M%S)"; DEST="backups/$TS"; mkdir -p "$DEST"
VOL="$(docker volume ls --format '{{.Name}}' | grep -E 'hindsight-crew_pg0$' | head -1)"
[ -n "$VOL" ] || { echo "backup: pg0 volume not found"; exit 1; }
docker run --rm -v "$VOL":/data:ro -v "$ROOT/$DEST":/backup alpine \
  sh -c 'tar czf /backup/pg0.tar.gz -C /data . 2>/dev/null'
F="$DEST/pg0.tar.gz"
SZ="$(stat -f%z "$F" 2>/dev/null || stat -c%s "$F" 2>/dev/null || echo 0)"
# HARD 0-byte guard: a near-empty archive means the backup silently failed.
[ "$SZ" -gt 2000 ] || { echo "backup GUARD FAIL: $F is only $SZ bytes"; exit 1; }
# retention (default 14 days)
find backups -maxdepth 1 -type d -name '20*' -mtime +"${HC_BACKUP_RETENTION_DAYS:-14}" -exec rm -rf {} + 2>/dev/null || true
echo "backup ok: $F ($SZ bytes)" >&2
echo "$F"
