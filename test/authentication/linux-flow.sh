#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$TEST_DIR/../.." && pwd)

# Sourcing must define Enroll_ElasticAgent without running the extension.
# shellcheck source=../../src/handler/linux/enable.sh
source "$REPO_ROOT/src/handler/linux/enable.sh" >/dev/null

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

curl_log=$(mktemp)
trap 'rm -f "$curl_log"' EXIT

curl() {
  auth_config=$(cat)
  printf '%s|%s\n' "$*" "$auth_config" >>"$curl_log"
  case "$*" in
    *"/api/fleet/setup"*)
      printf '%s\n' '{"isInitialized":true}'
      ;;
    *"/api/fleet/agent_policies?sys_monitoring=true"*)
      printf '%s\n' '{"item":{"id":"policy-123","name":"Azure VM extension policy","status":"active"}}'
      ;;
    *"/api/fleet/agent_policies"*)
      printf '%s\n' '{"items":[]}'
      ;;
    *"/api/fleet/enrollment-api-keys/enrollment-456"*)
      printf '%s\n' '{"item":{"api_key":"enrollment-token"}}'
      ;;
    *"/api/fleet/enrollment-api-keys"*)
      printf '%s\n' '{"list":[{"id":"enrollment-456","active":true,"policy_id":"policy-123"}]}'
      ;;
    *"/api/fleet/settings"*)
      printf '%s\n' '{"item":{"fleet_server_hosts":["https://fleet.example.test:443"]}}'
      ;;
    *)
      fail "unexpected curl request: $*"
      ;;
  esac
}

get_kibana_host() {
  KIBANA_URL="https://kibana.example.test"
}
get_api_key() {
  API_KEY="encoded-api-key"
}
get_password() {
  PASSWORD="fallback-password"
}
get_base64Auth() {
  BASE64_AUTH=""
}
get_username() {
  USERNAME="fallback-user"
}
log() {
  :
}
write_status() {
  :
}
set_sequence_to_file() {
  :
}
sudo() {
  :
}

STACK_VERSION="8.19.20"
Enroll_ElasticAgent

expected_paths='
/api/fleet/setup
/api/fleet/agent_policies
/api/fleet/agent_policies?sys_monitoring=true
/api/fleet/enrollment-api-keys
/api/fleet/enrollment-api-keys/enrollment-456
/api/fleet/settings
'
while IFS= read -r path; do
  if [ "$path" = "" ]; then
    continue
  fi
  if ! grep -F "$path" "$curl_log" >/dev/null; then
    fail "missing authenticated Fleet request: $path"
  fi
done <<EOF
$expected_paths
EOF

if grep -v 'Authorization: ApiKey encoded-api-key' "$curl_log" >/dev/null; then
  fail "every Fleet request must use API key authentication"
fi

while IFS= read -r request; do
  request_args=${request%%|*}
  case "$request_args" in
    *"encoded-api-key"*) fail "API key must not appear in curl process arguments" ;;
    *) ;;
  esac
done <"$curl_log"

printf 'ok - Linux Fleet API key flow test passed\n'
