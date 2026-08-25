#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=$(cd "$(dirname "$0")" && pwd)

bash "$TEST_DIR/linux-auth.sh"
bash "$TEST_DIR/linux-flow.sh"

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -File "$TEST_DIR/windows-auth.ps1"
elif command -v powershell >/dev/null 2>&1; then
  powershell -NoProfile -File "$TEST_DIR/windows-auth.ps1"
else
  printf 'skip - PowerShell is not installed; Windows auth test not run\n'
fi
