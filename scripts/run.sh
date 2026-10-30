#!/usr/bin/env bash
# Runs the pipeline's current revision. epack uses the ID token in
# LOCKTIVITY_ID_TOKEN once, to sign in when it fetches the revision. After that
# it gets its own GitHub ID tokens.
set -euo pipefail

# shellcheck source=scripts/id-token.sh
source "$(dirname "$0")/id-token.sh"

api_endpoint="${LOCKTIVITY_API_ENDPOINT%/}"
if [ "$api_endpoint" != "https://api.locktivity.com" ]; then
  export EPACK_INSECURE_CREDENTIAL_BROKER_URL="$api_endpoint"
  export EPACK_INSECURE_REMOTE_ENDPOINT="$api_endpoint"
  export EPACK_INSECURE_REMOTE_AUTH_ENDPOINT="$api_endpoint"
fi

# Run outside the workspace so that an epack.yaml checked out by an earlier
# step isn't used instead of the fetched revision.
work_dir="$RUNNER_TEMP/epack-ci"
mkdir -p "$work_dir"
cd "$work_dir"

mint_id_token "$api_endpoint"
export LOCKTIVITY_ID_TOKEN="$ID_TOKEN"
epack run "$EPACK_PIPELINE_ID" --remote locktivity --yes --output "$work_dir/evidence.epack"
