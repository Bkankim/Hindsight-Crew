#!/usr/bin/env bash
# seed-demo.sh — make the demo UNATTENDED: if .env.local is absent, generate the upstream
# key (CSPRNG), 2 demo member tokens, and a team-bank ACL. Idempotent: never overwrites an
# existing .env.local or secrets/acl.json. bash 3.2 compatible.
set -eu
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p secrets audit

rand() { openssl rand -hex "${1:-24}"; }   # CSPRNG

if [ ! -f .env.local ]; then
  KEY="hs_$(rand 24)"
  PGP="$(rand 16)"
  PROFILE="${HC_PROFILE:-cpu-en}"
  {
    echo "# AUTO-SEEDED by seed-demo.sh — DO NOT COMMIT (gitignored)"
    echo "HC_PROFILE=$PROFILE"
    echo "HC_HINDSIGHT_API_KEY=$KEY"
    echo "HC_PG_PASSWORD=$PGP"
    echo "HC_GATEWAY_BIND=127.0.0.1:8888"
    echo "HC_ATTRIBUTION_MODE=body-inject"
    # default to floating tags until digests are resolved (bootstrap can pin)
    echo "HC_HINDSIGHT_IMAGE=ghcr.io/vectorize-io/hindsight:latest"
    echo "HC_POSTGRES_IMAGE=postgres:16-alpine"
  } > .env.local
  # merge selected profile model vars
  if [ -f "profiles/$PROFILE.env" ]; then
    grep -E '^(HINDSIGHT_API_|HC_EMBED_DIM)' "profiles/$PROFILE.env" >> .env.local || true
  fi
  echo "seed-demo: wrote .env.local (profile=$PROFILE, key auto-generated)"
else
  echo "seed-demo: .env.local exists — left untouched"
fi

if [ ! -f secrets/acl.json ]; then
  TOK_ALICE="mt_$(rand 20)"
  TOK_BOB="mt_$(rand 20)"
  cat > secrets/acl.json <<EOF
{
  "tokens": {
    "$TOK_ALICE": {"identity": "alice", "personal": "personal-alice", "teams": ["team-eng"]},
    "$TOK_BOB":   {"identity": "bob",   "personal": "personal-bob",   "teams": ["team-eng"]}
  }
}
EOF
  # stash the demo tokens for verify gates (gitignored secrets dir)
  cat > secrets/demo-tokens.env <<EOF
HC_DEMO_TOKEN_ALICE=$TOK_ALICE
HC_DEMO_TOKEN_BOB=$TOK_BOB
EOF
  echo "seed-demo: wrote secrets/acl.json (alice, bob; team-eng) + demo-tokens.env"
else
  echo "seed-demo: secrets/acl.json exists — left untouched"
fi
