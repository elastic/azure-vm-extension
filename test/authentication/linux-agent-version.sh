#!/usr/bin/env bash
set -euo pipefail

# Checks how get_cloud_stack_version picks the Elastic Agent version:
# 1. the first plain x.y.z item of Fleet's available_versions (Kibana 8.4+),
#    skipping "+build" items, which have no package on artifacts.elastic.co;
# 2. otherwise Elasticsearch GET / version.number, unless the cluster is a
#    Serverless build, whose version number is not a release.

TEST_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$TEST_DIR/../.." && pwd)

# shellcheck source=../../src/handler/linux/enable.sh
source "$REPO_ROOT/src/handler/linux/enable.sh" >/dev/null

fail() {
  printf 'not ok - %s: %s\n' "$CASE" "$1" >&2
  exit 1
}

AVAILABLE_VERSIONS=""
ES_ROOT=""

curl() {
  cat >/dev/null
  local arg
  for arg in "$@"; do
    case "$arg" in
      https://kibana.example.test/api/fleet/agents/available_versions) printf '%s\n' "$AVAILABLE_VERSIONS"; return ;;
      https://es.example.test) printf '%s\n' "$ES_ROOT"; return ;;
      https://*) fail "unexpected request: $arg" ;;
    esac
  done
}

get_kibana_host() { KIBANA_URL="https://kibana.example.test"; }
get_elasticsearch_host() { ELASTICSEARCH_URL="https://es.example.test"; }
get_api_key() { API_KEY="aWQ6dGVzdC1hcGkta2V5"; }
get_password() { PASSWORD=""; }
get_base64Auth() { BASE64_AUTH=""; }
get_username() { USERNAME=""; }
log() { :; }
clean_and_exit() { exit "${1:-1}"; }

expect_version() {
  CASE=$1
  AVAILABLE_VERSIONS=$2
  ES_ROOT=$3
  local expected=$4 actual
  actual=$(STACK_VERSION=""; get_cloud_stack_version >/dev/null; printf '%s' "$STACK_VERSION") || fail "lookup failed"
  if [ "$actual" != "$expected" ]; then
    fail "expected '$expected', got '$actual'"
  fi
  printf 'ok - agent version: %s\n' "$CASE"
}

expect_failure() {
  CASE=$1
  AVAILABLE_VERSIONS=$2
  ES_ROOT=$3
  if (STACK_VERSION=""; get_cloud_stack_version >/dev/null 2>&1); then
    fail "expected the lookup to fail"
  fi
  printf 'ok - agent version: %s\n' "$CASE"
}

hosted_es='{"version":{"number":"9.5.6","build_flavor":"default"}}'

expect_version "Fleet list, latest first" \
  '{"items":["9.5.6","9.5.5","9.5.4+build202609161310"]}' "$hosted_es" "9.5.6"
expect_version "Fleet list, build item skipped" \
  '{"items":["9.5.4+build202609161310","9.5.4","9.5.3"]}' "$hosted_es" "9.5.4"
expect_version "Kibana before 8.4 falls back to Elasticsearch" \
  '{"statusCode":404,"error":"Not Found","message":"Not Found"}' \
  '{"version":{"number":"8.3.3","build_flavor":"default"}}' "8.3.3"
expect_version "key without Fleet agent read falls back to Elasticsearch" \
  '{"statusCode":403,"error":"Forbidden","message":"Forbidden"}' "$hosted_es" "9.5.6"
expect_failure "Serverless without Fleet list is rejected" \
  '{"statusCode":404,"error":"Not Found","message":"Not Found"}' \
  '{"version":{"number":"8.11.0","build_flavor":"serverless"}}'
expect_version "Serverless uses the Fleet list" \
  '{"items":["9.6.0","9.5.6"]}' \
  '{"version":{"number":"8.11.0","build_flavor":"serverless"}}' "9.6.0"
