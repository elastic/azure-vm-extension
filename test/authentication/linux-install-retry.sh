#!/usr/bin/env bash
set -euo pipefail

# install.sh installs curl and jq with the distro package manager. On a VM a
# few minutes old, name resolution or the package mirrors can fail for a while
# ("Temporary failure resolving ..."), and a single retry after 15 seconds
# failed the whole extension install with apt's exit code 100. The installs
# must keep retrying with growing waits, refreshing the package lists first.

if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  printf 'skip - install.sh needs bash 4 or later; install retry test not run\n'
  exit 0
fi

TEST_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$TEST_DIR/../.." && pwd)

# shellcheck source=../../src/handler/linux/install.sh
source "$REPO_ROOT/src/handler/linux/install.sh"

fail() {
  printf 'not ok - %s: %s\n' "$CASE" "$1" >&2
  exit 1
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Fakes: a Debian host where curl and jq are missing and apt-get install
# fails a given number of times before it works.
log() { :; }
sleep() { printf '%s\n' "$1" >>"$work/sleeps"; }
sudo() { "$@"; }
get_distro() { DISTRO_NAME=Ubuntu; DISTRO_VERSION=22.04; }
dpkg() { return 0; }
dpkg-query() { return 1; }
apt-get() {
  printf '%s\n' "$*" >>"$work/apt"
  case "$*" in
    update) return 0 ;;
    *install*)
      local failures
      failures=$(cat "$work/failures_left")
      if [ "$failures" -gt 0 ]; then
        printf '%s\n' "$((failures - 1))" >"$work/failures_left"
        return 100
      fi
      return 0
      ;;
  esac
}

run_case() {
  CASE=$1
  printf '%s\n' "$2" >"$work/failures_left"
  : >"$work/apt"
  : >"$work/sleeps"
  set +e
  (set -e; install_dependencies) >/dev/null 2>&1
  rc=$?
  set -e
}

run_case "transient apt failures are retried" 3
[ "$rc" -eq 0 ] || fail "install_dependencies failed with $rc after 3 transient failures"
installs=$(grep -c 'install' "$work/apt")
[ "$installs" -eq 5 ] || fail "expected 5 install attempts (4 for curl, 1 for jq), got $installs"
updates=$(grep -c '^update$' "$work/apt")
[ "$updates" -ge 4 ] || fail "package lists must be refreshed before each install attempt, got $updates updates"
[ "$(head -3 "$work/sleeps" | tr '\n' ' ')" = "15 30 60 " ] || fail "expected growing waits 15 30 60, got: $(tr '\n' ' ' <"$work/sleeps")"
printf 'ok - %s\n' "$CASE"

run_case "persistent apt failure stops after 5 attempts" 99
[ "$rc" -ne 0 ] || fail "install_dependencies must fail when apt never works"
installs=$(grep -c 'install' "$work/apt")
[ "$installs" -eq 5 ] || fail "expected 5 install attempts before giving up, got $installs"
printf 'ok - %s\n' "$CASE"
