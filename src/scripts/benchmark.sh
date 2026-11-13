#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/../backend"
exec npx tsx test/benchmark/run.ts
