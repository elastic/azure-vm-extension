#!/usr/bin/env bash
set -euo pipefail

for script in src/handler/linux/*.sh; do
  bash -n "$script"
done

python3 -B -m unittest discover -s test/upgrade -v

# Linux authentication and Fleet API compatibility tests need jq.
if ! command -v jq >/dev/null 2>&1; then
  apt-get update -qq >/dev/null
  apt-get install -y -qq jq >/dev/null
fi
bash test/authentication/run.sh
