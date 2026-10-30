#!/usr/bin/env bash
# Signs in for the pipeline to get the epack version its current revision uses,
# or to learn that it is paused. The session it returns is not used. Locktivity
# accepts each GitHub ID token only once, so epack signs in again with a new one.
set -euo pipefail

# shellcheck source=scripts/id-token.sh
source "$(dirname "$0")/id-token.sh"

fail() {
  local message="Sign-in to Locktivity failed (HTTP $status)"
  if [ -n "$error" ]; then message="$message: $error"; fi
  if [ -n "$1" ]; then message="$message. $1"; fi
  echo "::error::$(escape_command_data "$message")"
  exit 1
}

if [ "${RUNNER_OS:-}" != "Linux" ] || [ "${RUNNER_ARCH:-}" != "X64" ]; then
  echo "::error::This action runs on Linux x64 runners, such as ubuntu-latest."
  exit 1
fi

api_endpoint=$(locktivity_api)
if [[ ! "${EPACK_PIPELINE_ID:-}" =~ ^[A-Za-z0-9_-]{1,64}$ ]]; then
  echo "::error::pipeline-id must be the pipeline's ID, as shown on its page in Locktivity."
  exit 1
fi

if [ "$api_endpoint" != "https://api.locktivity.com" ]; then
  echo "::warning title=Not Locktivity's API::$(escape_command_data "This run signs in to $api_endpoint because EPACK_INSECURE_CREDENTIAL_BROKER_URL is set. Remove it unless you are testing against another Locktivity.")"
fi

mint_id_token "$api_endpoint"

body=$(mktemp "${RUNNER_TEMP:-/tmp}/epack-ci-session.XXXXXX")
trap 'rm -f "$body"' EXIT
status=$(printf 'Authorization: Bearer %s\n' "$ID_TOKEN" |
  curl -sS -X POST -H @- -o "$body" -w '%{http_code}' "$api_endpoint/oidc/v1/pipelines/$EPACK_PIPELINE_ID/session")
error=$(jq -r '.error // empty' "$body" 2>/dev/null || true)
description=$(jq -r '.error_description // empty' "$body" 2>/dev/null || true)

case "$status" in
  200)
    tag=$(jq -r '.epack_release_tag // empty' "$body")
    if [ -z "$tag" ]; then
      echo "::error::Locktivity returned no epack version for this pipeline. Check that the pipeline has a current revision."
      exit 1
    fi
    if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
      echo "::error::Locktivity returned an epack version this action can't install: $(escape_command_data "$tag")"
      exit 1
    fi
    echo "epack-release-tag=$tag" >>"$GITHUB_OUTPUT"
    echo "Signed in. The pipeline's current revision uses epack $tag."
    ;;
  401)
    fail "Locktivity refused this workflow's GitHub ID token"
    ;;
  403)
    if [ "$error" = "pipeline_paused" ]; then
      echo "::notice title=Pipeline paused::$(escape_command_data "${description:-The pipeline is paused in Locktivity.}")"
      echo "paused=true" >>"$GITHUB_OUTPUT"
      exit 0
    fi
    fail "Locktivity accepts sign-ins only from scheduled and manual runs of the pipeline's workflow file on the default branch"
    ;;
  404)
    fail "No managed pipeline with this ID runs from this repository. Check pipeline-id against the pipeline page"
    ;;
  *)
    fail ""
    ;;
esac
