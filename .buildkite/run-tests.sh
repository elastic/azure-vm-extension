#!/usr/bin/env bash
set -euo pipefail

for script in src/handler/linux/*.sh; do
  bash -n "$script"
done

python3 -B -m unittest discover -s test/upgrade -v
