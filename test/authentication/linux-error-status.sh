#!/usr/bin/env bash
set -euo pipefail

# A failed enable must leave an error status file. Without one, the Azure
# guest agent keeps reporting the extension as "transitioning", and Azure shows
# the extension as Creating (or a stale Succeeded) instead of Failed.
#
# The test copies the Linux handler into a fake extension folder and runs
# enable.sh with settings it cannot decrypt (no certificate), which is one of
# the handler's failure paths.

TEST_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$TEST_DIR/../.." && pwd)

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

ext="$work/elastic.ElasticAgent.linux-1.0.0"
mkdir -p "$ext/config" "$ext/status" "$work/logs" "$work/bin"
cp "$REPO_ROOT"/src/handler/linux/*.sh "$ext/"
cat >"$ext/HandlerEnvironment.json" <<EOF
[{"handlerEnvironment":{"logFolder":"$work/logs","configFolder":"$ext/config","statusFolder":"$ext/status"}}]
EOF
cat >"$ext/config/3.settings" <<'EOF'
{"runtimeSettings":[{"handlerSettings":{"protectedSettingsCertThumbprint":"MISSING","protectedSettings":"bm90LWVuY3J5cHRlZA==","publicSettings":{"cloudId":"test:ZXhhbXBsZS50ZXN0OjQ0MyRlcyRrYg=="}}}]}
EOF

# Fake Debian tools so the handler reaches its install path without systemd.
printf '#!/bin/sh\nexit 0\n' >"$work/bin/dpkg"
printf '#!/bin/sh\nexit 0\n' >"$work/bin/systemctl"
printf '#!/bin/sh\nexit 0\n' >"$work/bin/sudo"
chmod +x "$work/bin/"*

set +e
PATH="$work/bin:$PATH" bash "$ext/enable.sh" >"$work/out" 2>&1
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
  fail "enable.sh should fail without a decryption certificate"
fi
if ! grep -q 'Decryption failed' "$work/logs/es-agent.log"; then
  fail "enable.sh failed for an unexpected reason: $(tail -3 "$work/logs/es-agent.log")"
fi
status_file="$ext/status/3.status"
if [ ! -f "$status_file" ]; then
  fail "a failed enable must write $status_file"
fi
status=$(jq -r '.[0].status.status' "$status_file")
substatus=$(jq -r '.[0].status.substatus[0].status' "$status_file")
code=$(jq -r '.[0].status.substatus[0].code' "$status_file")
if [ "$status" != "error" ] || [ "$substatus" != "error" ] || [ "$code" != "1" ]; then
  fail "expected an error status, got status=$status substatus=$substatus code=$code"
fi
printf 'ok - Linux failed enable writes an error status\n'
