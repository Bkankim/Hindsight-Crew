#!/usr/bin/env bash
# restore-test.sh — prove a backup actually restores: extract pg0 into a throwaway volume,
# boot a throwaway hindsight on it (sharing the model cache for speed), and recall a memory
# that existed before the backup. Success = data survived AND the app works on restored data.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"
[ -f .env.local ] && { set -a; . ./.env.local; set +a; }
F="${1:-$(ls -t backups/*/pg0.tar.gz 2>/dev/null | head -1)}"
[ -f "$F" ] || { echo "restore-test: no backup file"; exit 1; }
IMG="${HC_HINDSIGHT_IMAGE:-ghcr.io/vectorize-io/hindsight:latest}"
KEY="${HC_HINDSIGHT_API_KEY:?}"
RV=hc-restore-pg0; RC=hc-restore-hs; PORT=18899
HF="$(docker volume ls --format '{{.Name}}' | grep -E 'hindsight-crew_hfcache$' | head -1)"
MAIN_WAS_UP=0
if docker compose --env-file .env.local ps --status running 2>/dev/null | grep -q hindsight; then MAIN_WAS_UP=1; fi
cleanup(){ docker rm -f "$RC" >/dev/null 2>&1 || true; docker volume rm "$RV" >/dev/null 2>&1 || true; [ "$MAIN_WAS_UP" = 1 ] && docker compose --env-file .env.local start hindsight >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup
[ "$MAIN_WAS_UP" = 1 ] && { echo "restore-test: stopping main hindsight to free RAM for throwaway" >&2; docker compose --env-file .env.local stop hindsight >/dev/null 2>&1 || true; }
docker volume create "$RV" >/dev/null
docker run --rm -v "$RV":/data -v "$ROOT/$(dirname "$F")":/b alpine sh -c "tar xzf /b/$(basename "$F") -C /data" || { echo "restore extract failed"; exit 1; }
HFARG=""; [ -n "$HF" ] && HFARG="-v $HF:/home/hindsight/.cache/huggingface"
docker run -d --name "$RC" \
  -e HINDSIGHT_API_MCP_AUTH_TOKEN="$KEY" -e HINDSIGHT_API_LLM_PROVIDER=none \
  -e HINDSIGHT_API_EMBEDDINGS_MODEL=BAAI/bge-small-en-v1.5 \
  -e HINDSIGHT_API_RERANKER_MODEL=cross-encoder/ms-marco-MiniLM-L-6-v2 \
  -v "$RV":/home/hindsight/.pg0 $HFARG -p 127.0.0.1:$PORT:8888 "$IMG" >/dev/null || { echo "restore boot failed"; exit 1; }
ok=0
for i in $(seq 1 50); do
  c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$PORT/health" 2>/dev/null || echo 000)
  [ "$c" = "200" ] && { ok=1; break; }; sleep 3
done
[ "$ok" = "1" ] || { echo "restored stack not healthy"; docker logs "$RC" 2>&1 | tail -8; exit 1; }
body=$(curl -s --max-time 25 -X POST "http://127.0.0.1:$PORT/v1/default/banks/team-eng/memories/recall" \
  -H "authorization: Bearer $KEY" -H 'content-type: application/json' -d '{"query":"release freeze"}')
echo "$body" | grep -qi "release freeze" && { echo "restore-test ok: data survived + recall works on restored stack"; exit 0; }
echo "restore-test FAIL: marker not recalled: $(echo "$body" | head -c 160)"; exit 1
