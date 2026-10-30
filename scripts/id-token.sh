# shellcheck shell=bash
# Sourced by the scripts that sign in.

# The Locktivity API runs sign in to, and the audience of their ID tokens.
# epack's EPACK_INSECURE_CREDENTIAL_BROKER_URL points epack at another
# Locktivity for testing, so the action's own sign-in follows it too.
locktivity_api() {
  local api="${EPACK_INSECURE_CREDENTIAL_BROKER_URL:-https://api.locktivity.com}"
  printf '%s' "${api%/}"
}

# Sets ID_TOKEN to a GitHub Actions ID token for the audience in $1 and
# masks it in the job log.
mint_id_token() {
  if [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ] || [ -z "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" ]; then
    echo "::error::This job can't get a GitHub ID token. Add id-token: write to the workflow's permissions."
    return 1
  fi

  local separator="?" audience response
  case "$ACTIONS_ID_TOKEN_REQUEST_URL" in *\?*) separator="&" ;; esac
  audience=$(jq -rn --arg value "$1" '$value | @uri')
  response=$(printf 'Authorization: Bearer %s\n' "$ACTIONS_ID_TOKEN_REQUEST_TOKEN" |
    curl -sSf --retry 3 -H @- "${ACTIONS_ID_TOKEN_REQUEST_URL}${separator}audience=${audience}")
  ID_TOKEN=$(jq -r '.value // empty' <<<"$response")
  if [ -z "$ID_TOKEN" ]; then
    echo "::error::GitHub returned no ID token."
    return 1
  fi
  echo "::add-mask::$ID_TOKEN"
}

# Escapes workflow command text so that a line break in it can't start another
# command.
escape_command_data() {
  local data="$1"
  data="${data//'%'/%25}"
  data="${data//$'\r'/%0D}"
  data="${data//$'\n'/%0A}"
  printf '%s' "$data"
}
