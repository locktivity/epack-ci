#!/usr/bin/env bash
# Runs the action's scripts against test/fixture_server.py. Each sign-in case
# uses a pipeline ID that tells the fixture how to answer. The run cases put a
# stub epack on PATH that records what it was given.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d)
python3 -I "$root/test/fixture_server.py" "$scratch/port" &
server=$!
disown "$server"
trap 'kill "$server" 2>/dev/null || true; rm -rf "$scratch"' EXIT

for _ in $(seq 50); do
  if [ -s "$scratch/port" ]; then break; fi
  sleep 0.1
done
port=$(cat "$scratch/port")

failures=0
token_url="http://127.0.0.1:$port/token?api-version=2.0"

sign_in() {
  : >"$scratch/output"
  set +e
  out=$(EPACK_PIPELINE_ID="$1" EPACK_INSECURE_CREDENTIAL_BROKER_URL="http://127.0.0.1:$port/" \
    ACTIONS_ID_TOKEN_REQUEST_URL="${2-$token_url}" ACTIONS_ID_TOKEN_REQUEST_TOKEN="request-token" \
    GITHUB_OUTPUT="$scratch/output" RUNNER_TEMP="$scratch" RUNNER_OS="${3-Linux}" RUNNER_ARCH="${4-X64}" \
    bash "$root/scripts/sign-in.sh" 2>&1)
  status=$?
  set -e
  outputs=$(cat "$scratch/output")
}

check() {
  local name="$1"
  shift
  if "$@"; then
    echo "ok - $name"
  else
    echo "not ok - $name"
    printf '%s\n' "$out" | sed 's/^/    /'
    failures=$((failures + 1))
  fi
}

contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }

sign_in current
check "a current revision names its epack release" [ "$status" -eq 0 ]
check "the release goes to the step's outputs" [ "$outputs" = "epack-release-tag=v0.9.4" ]
check "the ID token is masked" contains "$out" "::add-mask::id-token-for:http"
check "the session's access token is never printed" lacks "$out" "ltk_fixture_session"
check "the session response is not kept" [ -z "$(find "$scratch" -name 'epack-ci-session.*')" ]
check "signing in to another Locktivity is flagged on the run" contains "$out" "::warning title=Not Locktivity's API::This run signs in to http://127.0.0.1:$port because EPACK_INSECURE_CREDENTIAL_BROKER_URL is set."

sign_in paused
check "a paused pipeline ends without failing" [ "$status" -eq 0 ]
check "a paused pipeline says why in one notice" contains "$out" "::notice title=Pipeline paused::This pipeline is paused. Resume it on its page."
check "a paused pipeline skips the rest" [ "$outputs" = "paused=true" ]

sign_in refused
check "a refused run fails" [ "$status" -eq 1 ]
check "a refused run names the server's reason and the rule" contains "$out" "(HTTP 403): Workflow run is not allowed for this pipeline. Locktivity accepts sign-ins only from scheduled and manual runs"

sign_in missing
check "an unknown pipeline fails" [ "$status" -eq 1 ]
check "an unknown pipeline points at pipeline-id" contains "$out" "(HTTP 404): Not found. No managed pipeline with this ID runs from this repository"

sign_in no-revision
check "a pipeline with no epack version fails" [ "$status" -eq 1 ]
check "a pipeline with no epack version says so" contains "$out" "returned no epack version"

sign_in odd-tag
check "a malformed epack version fails" [ "$status" -eq 1 ]
check "a malformed epack version is not passed on" [ -z "$outputs" ]

sign_in multiline
check "a server message can't start another workflow command" lacks "$out" $'\n::warning::'
check "a server message keeps its second line, escaped" contains "$out" "first line%0A::warning::second line"

sign_in "../current"
check "a malformed pipeline ID fails before signing in" [ "$status" -eq 1 ]
check "a malformed pipeline ID says what it should be" contains "$out" "pipeline-id must be the pipeline's ID"

sign_in current ""
check "a job without id-token: write fails" [ "$status" -eq 1 ]
check "a job without id-token: write names the permission" contains "$out" "Add id-token: write to the workflow's permissions"

sign_in current "$token_url" macOS ARM64
check "a macOS runner fails before signing in" [ "$status" -eq 1 ]
check "a macOS runner names the runners this action needs" contains "$out" "runs on Linux x64 runners"

sign_in current "$token_url" Linux ARM64
check "an arm64 Linux runner fails before signing in" [ "$status" -eq 1 ]

mkdir -p "$scratch/bin"
cat >"$scratch/bin/epack" <<'STUB'
#!/usr/bin/env bash
{
  echo "args=$*"
  echo "cwd=$PWD"
  env | grep -E '^(LOCKTIVITY_ID_TOKEN|EPACK_)' | sort
} >"$EPACK_STUB_LOG"
STUB
chmod +x "$scratch/bin/epack"

run_pipeline() {
  set +e
  out=$(env ${1:+"EPACK_INSECURE_CREDENTIAL_BROKER_URL=$1"} PATH="$scratch/bin:$PATH" EPACK_STUB_LOG="$scratch/epack.log" \
    EPACK_PIPELINE_ID="current" EPACK_TRUSTED_PUBLISHERS="locktivity,acme" \
    ACTIONS_ID_TOKEN_REQUEST_URL="$token_url" ACTIONS_ID_TOKEN_REQUEST_TOKEN="request-token" RUNNER_TEMP="$scratch" \
    bash "$root/scripts/run.sh" 2>&1)
  status=$?
  set -e
  epack_saw=$(cat "$scratch/epack.log")
}

run_pipeline ""
check "a run starts epack" [ "$status" -eq 0 ]
check "epack runs the pipeline by ID and writes the pack where the upload looks" contains "$epack_saw" "args=run current --remote locktivity --yes --output $scratch/epack-ci/evidence.epack"
check "epack runs outside the workspace" contains "$epack_saw" "cwd=$scratch/epack-ci"
check "epack gets an ID token for the Locktivity audience" contains "$epack_saw" "LOCKTIVITY_ID_TOKEN=id-token-for:https://api.locktivity.com"
check "epack gets the trusted publishers" contains "$epack_saw" "EPACK_TRUSTED_PUBLISHERS=locktivity,acme"
check "a production run sets no endpoint overrides" lacks "$epack_saw" "EPACK_INSECURE_"
check "the run masks the ID token" contains "$out" "::add-mask::id-token-for:https://api.locktivity.com"

run_pipeline "https://dev.example.test/"
check "an insecure broker URL is the ID token's audience" contains "$epack_saw" "LOCKTIVITY_ID_TOKEN=id-token-for:https://dev.example.test"
check "the action adds no endpoint overrides of its own" lacks "$epack_saw" "EPACK_INSECURE_REMOTE"

if [ "$failures" -gt 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
