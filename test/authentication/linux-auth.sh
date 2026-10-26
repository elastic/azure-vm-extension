#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$TEST_DIR/../.." && pwd)

# shellcheck source=../../src/handler/linux/helper.sh
source "$REPO_ROOT/src/handler/linux/helper.sh"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_auth_header() {
  expected=$1
  description=$2

  if [ "$AUTHORIZATION_HEADER" != "$expected" ]; then
    fail "$description"
  fi
}

set_auth_header "aWQ6dGVzdC1hcGkta2V5" "fallback-user" "fallback-password" \
  "$(printf 'base64-user:base64-password' | base64)"
assert_auth_header "Authorization: ApiKey aWQ6dGVzdC1hcGkta2V5" \
  "API key takes precedence over Basic credentials"

set_auth_header "" "fallback-user" "fallback-password" ""
expected_basic=$(printf 'fallback-user:fallback-password' | base64 | tr -d '\n')
assert_auth_header "Authorization: Basic $expected_basic" \
  "username and password remain a Basic-auth fallback"

encoded_basic=$(printf 'base64-user:base64-password' | base64 | tr -d '\n')
set_auth_header "null" "" "null" "$encoded_basic"
assert_auth_header "Authorization: Basic $encoded_basic" \
  "base64Auth remains a Basic-auth fallback"

if set_auth_header "" "" "" ""; then
  fail "missing credentials must be rejected"
fi

# Accept standard Base64 with no padding, either padding length, and +/.
for api_key in 'aWQ6a2V5' 'aWQ6YWI=' 'aWQ6YQ==' 'aWQ6fn5+' 'aWQ6Pz8/'; do
  set_auth_header "$api_key" "" "" ""
  assert_auth_header "Authorization: ApiKey $api_key" \
    "valid Base64 API keys must be accepted"
done

# A malformed explicit key must fail even when Basic credentials are available.
for api_key in 'encoded-api-key' 'YWJ' 'A===' 'AA=A' 'YWJj====' \
  'YW Jj' $'YWJj\t' $'YWJj\r' $'YWJj\n' 'YWJj"' 'YWJj\' \
  $'YWJj"\nheader = "X-Injected: yes'; do
  set_auth_header 'aWQ6a2V5' "" "" ""
  if set_auth_header "$api_key" "fallback-user" "fallback-password" "$encoded_basic"; then
    fail "malformed API keys must be rejected without Basic-auth fallback"
  fi
  assert_auth_header "" "rejected API keys must clear the previous header"
done

curl_stdin=$(mktemp)
curl_log=$(mktemp)
trap 'rm -f "$curl_stdin" "$curl_log"' EXIT
curl() {
  printf '%s\n' "$*" >"$curl_log"
  cat >"$curl_stdin"
  printf '%s\n' '{"version":{"number":"8.19.20"}}'
}

set_auth_header "aWQ6dGVzdC1hcGkta2V5" "" "" ""
authenticated_curl "https://elasticsearch.example.test" >/dev/null
curl_args=$(<"$curl_log")
curl_input=$(<"$curl_stdin")
case "$curl_args" in
  *"aWQ6dGVzdC1hcGkta2V5"*) fail "API key must not appear in curl process arguments" ;;
  *) ;;
esac
case "$curl_input" in
  *"Authorization: ApiKey aWQ6dGVzdC1hcGkta2V5"*) ;;
  *) fail "curl must receive the API key header through standard input" ;;
esac

set_auth_header "null" "" "null" \
  "$(printf 'base64-user:base64-password' | base64)"
log() {
  :
}
get_elasticsearch_host() {
  ELASTICSEARCH_URL="https://elasticsearch.example.test"
}
get_api_key() {
  API_KEY="aWQ6dGVzdC1hcGkta2V5"
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

get_cloud_stack_version
curl_args=$(<"$curl_log")
curl_input=$(<"$curl_stdin")
case "$curl_args" in
  *"aWQ6dGVzdC1hcGkta2V5"*) fail "version discovery exposes the API key in process arguments" ;;
  *) ;;
esac
case "$curl_input" in
  *"Authorization: ApiKey aWQ6dGVzdC1hcGkta2V5"*) ;;
  *) fail "Elasticsearch version discovery must use API key authentication" ;;
esac

printf 'ok - Linux authentication selection tests passed\n'
