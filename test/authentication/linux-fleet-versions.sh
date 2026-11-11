#!/usr/bin/env bash
set -euo pipefail

# Runs Enroll_ElasticAgent against fake Kibana Fleet APIs shaped like each
# supported stack line and checks the resulting `elastic-agent enroll` call.
#
#   hosted9 - Kibana 9.x: `enrollment-api-keys` is gone (404), list responses
#             only have `items`, and /api/fleet/settings has no
#             `fleet_server_hosts` (the host comes from /api/fleet/fleet_server_hosts).
#   hosted8 - Kibana 8.19: both old and new shapes are served.
#   legacy  - Kibana before the underscore/fleet_server_hosts APIs: only
#             `enrollment-api-keys` with `list`, Fleet Server host in settings.

TEST_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$TEST_DIR/../.." && pwd)

# shellcheck source=../../src/handler/linux/enable.sh
source "$REPO_ROOT/src/handler/linux/enable.sh" >/dev/null

fail() {
  printf 'not ok - %s: %s\n' "$SCENARIO" "$1" >&2
  exit 1
}

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

not_found() {
  printf '%s\n' '{"statusCode":404,"error":"Not Found","message":"Not Found"}'
}

curl() {
  cat >/dev/null
  local url="" arg
  for arg in "$@"; do
    case "$arg" in
      https://*) url="$arg" ;;
    esac
  done
  printf '%s\n' "$url" >>"$work_dir/requests"
  local path=${url#https://kibana.example.test}
  case "$SCENARIO:$path" in
    *:/api/fleet/setup)
      printf '%s\n' '{"isInitialized":true}' ;;
    *:/api/fleet/agent_policies)
      printf '%s\n' '{"items":[{"id":"other-policy","name":"Other","status":"active"},{"id":"policy-123","name":"Azure VM extension policy","status":"active"}],"total":2,"page":1,"perPage":20}' ;;

    hosted9:/api/fleet/enrollment_api_keys*)
      case "$path" in
        */enrollment_api_keys/key-azure*) printf '%s\n' '{"item":{"id":"key-azure","api_key":"token-azure","policy_id":"policy-123","active":true}}' ;;
        */enrollment_api_keys/*) not_found ;;
        *) printf '%s\n' '{"items":[{"id":"key-other","api_key":"token-other","active":true,"policy_id":"other-policy"},{"id":"key-azure","api_key":"token-azure","active":true,"policy_id":"policy-123"}],"total":2,"page":1,"perPage":20}' ;;
      esac ;;
    hosted9:/api/fleet/enrollment-api-keys*) not_found ;;
    hosted9:/api/fleet/settings)
      printf '%s\n' '{"item":{"id":"fleet-default-settings","prerelease_integrations_enabled":false}}' ;;
    hosted9:/api/fleet/fleet_server_hosts)
      printf '%s\n' '{"items":[{"id":"other","name":"Other","host_urls":["https://other.example.test:443"],"is_default":false},{"id":"fleet-default-fleet-server-host","name":"Default","host_urls":["https://fleet9.example.test:443"],"is_default":true}],"total":2,"page":1,"perPage":10000}' ;;

    hosted8:/api/fleet/enrollment_api_keys*|hosted8:/api/fleet/enrollment-api-keys*)
      case "$path" in
        */key-azure*) printf '%s\n' '{"item":{"id":"key-azure","api_key":"token-azure","policy_id":"policy-123","active":true}}' ;;
        */enrollment?api?keys/*) not_found ;;
        *) printf '%s\n' '{"list":[{"id":"key-azure","api_key":"token-azure","active":true,"policy_id":"policy-123"}],"items":[{"id":"key-azure","api_key":"token-azure","active":true,"policy_id":"policy-123"}],"total":1,"page":1,"perPage":20}' ;;
      esac ;;
    hosted8:/api/fleet/settings)
      printf '%s\n' '{"item":{"id":"fleet-default-settings","fleet_server_hosts":["https://fleet8.example.test:443"]}}' ;;
    hosted8:/api/fleet/fleet_server_hosts)
      printf '%s\n' '{"items":[{"id":"fleet-default-fleet-server-host","name":"Default","host_urls":["https://fleet8.example.test:443"],"is_default":true}],"total":1,"page":1,"perPage":10000}' ;;

    legacy:/api/fleet/enrollment-api-keys*)
      case "$path" in
        */enrollment-api-keys/key-azure*) printf '%s\n' '{"item":{"id":"key-azure","api_key":"token-azure","policy_id":"policy-123","active":true}}' ;;
        */enrollment-api-keys/*) not_found ;;
        *) printf '%s\n' '{"list":[{"id":"key-azure","active":true,"policy_id":"policy-123"}],"total":1,"page":1,"perPage":20}' ;;
      esac ;;
    legacy:/api/fleet/enrollment_api_keys*) not_found ;;
    legacy:/api/fleet/fleet_server_hosts) not_found ;;
    legacy:/api/fleet/settings)
      printf '%s\n' '{"item":{"id":"fleet-default-settings","fleet_server_hosts":["https://fleet7.example.test:443"]}}' ;;

    *) fail "unexpected curl request: $url" ;;
  esac
}

get_kibana_host() { KIBANA_URL="https://kibana.example.test"; }
get_api_key() { API_KEY="aWQ6dGVzdC1hcGkta2V5"; }
get_password() { PASSWORD=""; }
get_base64Auth() { BASE64_AUTH=""; }
get_username() { USERNAME=""; }
log() { :; }
write_status() { :; }
set_sequence_to_file() { :; }
sudo() { printf '%s\n' "$*" >>"$work_dir/sudo"; }

run_scenario() {
  SCENARIO=$1
  local stack_version=$2 expected_enroll=$3
  : >"$work_dir/requests"
  : >"$work_dir/sudo"
  POLICY_ID=""
  STACK_VERSION=$stack_version
  if ! (Enroll_ElasticAgent) >"$work_dir/out" 2>&1; then
    fail "Enroll_ElasticAgent failed: $(tail -3 "$work_dir/out")"
  fi
  local actual
  actual=$(grep 'elastic-agent enroll' "$work_dir/sudo" || true)
  if [ "$actual" != "$expected_enroll" ]; then
    fail "expected enroll call '$expected_enroll', got '$actual'"
  fi
  printf 'ok - %s Fleet enrollment (%s)\n' "$SCENARIO" "$stack_version"
}

run_scenario hosted9 9.2.1 'elastic-agent enroll --url=https://fleet9.example.test:443 --enrollment-token=token-azure -f'
if grep -F '/api/fleet/enrollment-api-keys' "$work_dir/requests" >/dev/null; then
  fail "9.x flow must not call the removed enrollment-api-keys endpoint"
fi
run_scenario hosted8 8.19.25 'elastic-agent enroll --url=https://fleet8.example.test:443 --enrollment-token=token-azure -f'
run_scenario legacy 7.17.0 'elastic-agent enroll --url=https://fleet7.example.test:443 --enrollment-token=token-azure -f'
