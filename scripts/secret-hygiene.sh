#!/usr/bin/env bash
# secret-hygiene.sh — block secret leakage in a PUBLIC repo.
# Use as a pre-commit hook (scans staged files) or standalone (scans tracked files).
#   pre-commit:   scripts/secret-hygiene.sh --staged
#   full scan:    scripts/secret-hygiene.sh
# Exit 0 = clean, 1 = potential secret found (commit should be blocked).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mode="${1:-full}"
# Portable file collection (bash 3.2 compatible — no mapfile/readarray).
files=()
while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done < <(
  if [ "$mode" = "--staged" ]; then
    git diff --cached --name-only --diff-filter=ACM 2>/dev/null
  else
    git ls-files 2>/dev/null
  fi
)
[ "${#files[@]}" -eq 0 ] && { echo "secret-hygiene: no files to scan"; exit 0; }

declare -i hits=0
flag() { echo "  LEAK[$1]: $2"; hits+=1; }

# 1) Files that must NEVER be tracked.
for f in "${files[@]}"; do
  case "$f" in
    .env.local|*.local|secrets/*|*.key|*.pem|audit*.log)
      flag "forbidden-path" "$f (must be gitignored, never committed)";;
  esac
done

# 2) Content patterns. .env.example is allowed to contain REPLACE_* placeholders only.
scan() {
  local f="$1"
  [ -f "$f" ] || return 0
  # Private keys
  grep -Eq -- '-----BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY-----' "$f" && flag "private-key" "$f"
  # Hindsight bearer / generic high-entropy assignments with a real-looking value
  while IFS= read -r line; do
    # skip obvious placeholders
    case "$line" in *REPLACE*|*AUTOSEED*|*example*|*EXAMPLE*|*your-*|*xxxx*) continue;; esac
    flag "kv-secret" "$f: ${line%%=*}=<redacted>"
  done < <(grep -En -- '(API_KEY|SECRET|TOKEN|BEARER|PASSWORD|PASSWD)[A-Z_]*\s*[:=]\s*[A-Za-z0-9_/+\-]{16,}' "$f" 2>/dev/null | cut -d: -f2-)
}
for f in "${files[@]}"; do
  case "$f" in *.env.example) continue;; esac   # template is allowed placeholders
  scan "$f"
done

if [ "$hits" -gt 0 ]; then
  echo "secret-hygiene: FAIL — $hits potential secret(s). Commit blocked."
  exit 1
fi
echo "secret-hygiene: clean (${#files[@]} files scanned)"
exit 0
