#!/usr/bin/env bash
# profile-detect.sh — pick the embedding/model profile for an UNATTENDED boot.
# Default: cpu-en (the only v1-fully-verified profile). Flags opt into unverified profiles.
#   --korean -> ko-full   --gpu -> gpu   (else cpu-en)
# Prints the chosen profile name to stdout. Profile is locked at boot-0 (embedding dim).
set -eu
prof="cpu-en"
for a in "$@"; do
  case "$a" in
    --korean) prof="ko-full" ;;
    --gpu)    prof="gpu" ;;
    --profile=*) prof="${a#--profile=}" ;;
  esac
done
# Safety: a GPU profile on a host with no NVIDIA runtime cannot boot unattended -> warn to stderr.
if [ "$prof" = "gpu" ] && ! docker info 2>/dev/null | grep -qi nvidia; then
  echo "profile-detect: WARNING gpu profile requested but no NVIDIA runtime detected; boot may fail" >&2
fi
echo "$prof"
