#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=$(cd "$(dirname "$0")" && pwd)

bash "$TEST_DIR/linux-auth.sh"
bash "$TEST_DIR/linux-flow.sh"
bash "$TEST_DIR/linux-fleet-versions.sh"
bash "$TEST_DIR/linux-agent-version.sh"

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -File "$TEST_DIR/windows-auth.ps1"
  pwsh -NoProfile -File "$TEST_DIR/windows-fleet-versions.ps1"
  pwsh -NoProfile -File "$TEST_DIR/windows-agent-version.ps1"
elif command -v powershell >/dev/null 2>&1; then
  powershell -NoProfile -File "$TEST_DIR/windows-auth.ps1"
  powershell -NoProfile -File "$TEST_DIR/windows-fleet-versions.ps1"
  powershell -NoProfile -File "$TEST_DIR/windows-agent-version.ps1"
else
  printf 'skip - PowerShell is not installed; Windows auth test not run\n'
fi
