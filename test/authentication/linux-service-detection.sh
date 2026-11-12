#!/usr/bin/env bash
set -euo pipefail

# Run_Agent_DEB_RPM must recognise an installed elastic-agent unit in every
# `systemctl list-units --no-legend` format. Since systemd 246 the output keeps
# a leading status column ("  " or "● " for a failed unit), so splitting on a
# single space read the unit name as empty: on Ubuntu 22.04, RHEL 9 and
# Debian 11+ every enable reinstalled and re-enrolled the agent, leaving an
# offline duplicate in Fleet.

TEST_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$TEST_DIR/../.." && pwd)

# shellcheck source=../../src/handler/linux/enable.sh
source "$REPO_ROOT/src/handler/linux/enable.sh" >/dev/null

fail() {
  printf 'not ok - %s: %s\n' "$CASE" "$1" >&2
  exit 1
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

UNIT_LINE=""
ACTIVE=0
systemctl() {
  case "${1:-}" in
    "") printf '%s\n' '  -.mount loaded active mounted Root Mount' ;;
    list-units) [ -n "$UNIT_LINE" ] && printf '%s\n' "$UNIT_LINE"; return 0 ;;
    is-active) return "$ACTIVE" ;;
  esac
}
sudo() { "$@"; }
log() { :; }
retry_backoff() { "$@"; }
is_new_config() { IS_NEW_CONFIG=false; }
Install_ElasticAgent() { printf 'install\n' >>"$work/calls"; }
Start_ElasticAgent() { printf 'start\n' >>"$work/calls"; }
Reconfigure_Elastic_agent_DEB_RPM() { printf 'reconfigure\n' >>"$work/calls"; }

expect() {
  CASE=$1
  UNIT_LINE=$2
  ACTIVE=$3
  local expected=$4 actual
  : >"$work/calls"
  (Run_Agent_DEB_RPM) >/dev/null 2>&1 || fail "Run_Agent_DEB_RPM failed"
  actual=$(tr '\n' ' ' <"$work/calls" | sed 's/ $//')
  [ "$actual" = "$expected" ] || fail "expected '${expected:-nothing}', got '${actual:-nothing}'"
  printf 'ok - service detection: %s\n' "$CASE"
}

expect "systemd before 246, running unit" \
  'elastic-agent.service loaded active running Elastic Agent' 0 ""
expect "systemd 246 and later, running unit" \
  '  elastic-agent.service loaded active running Elastic Agent' 0 ""
expect "systemd 246 and later, stopped unit is started" \
  '  elastic-agent.service loaded inactive dead Elastic Agent' 3 "start"
expect "systemd 246 and later, failed unit with marker is started" \
  '● elastic-agent.service loaded failed failed Elastic Agent' 3 "start"
expect "no unit installs the agent" \
  '' 3 "install"
expect "not-found unit installs the agent" \
  '  elastic-agent.service not-found inactive dead elastic-agent.service' 3 "install"
