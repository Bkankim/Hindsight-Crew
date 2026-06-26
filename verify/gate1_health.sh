#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "$HERE/lib.sh"
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$HC_GW/healthz")
[ "$code" = "200" ] && { hc_log "gateway /healthz 200"; exit 0; }
hc_log "gateway health = $code"; exit 1
