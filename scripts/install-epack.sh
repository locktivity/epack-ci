#!/usr/bin/env bash
# Installs the epack release in EPACK_RELEASE_TAG after verifying its SLSA
# provenance against the epack repository at that tag.
set -euo pipefail

: "${EPACK_RELEASE_TAG:?EPACK_RELEASE_TAG must be set}"
: "${RUNNER_TEMP:?RUNNER_TEMP must be set}"

asset="epack-linux-amd64"
release="https://github.com/locktivity/epack/releases/download/${EPACK_RELEASE_TAG}"
download="$RUNNER_TEMP/$asset"
curl -sSfL --retry 3 "$release/$asset" -o "$download"
curl -sSfL --retry 3 "$release/$asset.intoto.jsonl" -o "$download.intoto.jsonl"

slsa-verifier verify-artifact "$download" \
  --provenance-path "$download.intoto.jsonl" \
  --source-uri github.com/locktivity/epack \
  --source-tag "$EPACK_RELEASE_TAG"

mkdir -p "$HOME/.epack/bin"
install -m 0755 "$download" "$HOME/.epack/bin/epack"
echo "$HOME/.epack/bin" >>"$GITHUB_PATH"
