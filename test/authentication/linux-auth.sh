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

set_auth_header "encoded-api-key" "fallback-user" "fallback-password" \
  "$(printf 'base64-user:base64-password' | base64)"
assert_auth_header "Authorization: ApiKey encoded-api-key" \
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

curl_stdin=$(mktemp)
curl_log=$(mktemp)
trap 'rm -f "$curl_stdin" "$curl_log"' EXIT
curl() {
  printf '%s\n' "$*" >"$curl_log"
  cat >"$curl_stdin"
  printf '%s\n' '{"version":{"number":"8.19.20"}}'
}

set_auth_header "encoded-api-key" "" "" ""
authenticated_curl "https://elasticsearch.example.test" >/dev/null
curl_args=$(<"$curl_log")
curl_input=$(<"$curl_stdin")
case "$curl_args" in
  *"encoded-api-key"*) fail "API key must not appear in curl process arguments" ;;
  *) ;;
esac
case "$curl_input" in
  *"Authorization: ApiKey encoded-api-key"*) ;;
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

get_cloud_stack_version
curl_args=$(<"$curl_log")
curl_input=$(<"$curl_stdin")
case "$curl_args" in
  *"encoded-api-key"*) fail "version discovery exposes the API key in process arguments" ;;
  *) ;;
esac
case "$curl_input" in
  *"Authorization: ApiKey encoded-api-key"*) ;;
  *) fail "Elasticsearch version discovery must use API key authentication" ;;
esac

printf 'ok - Linux authentication selection tests passed\n'
