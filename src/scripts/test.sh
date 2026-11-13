#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
export TEST_DATABASE_URL="${TEST_DATABASE_URL:-postgres://sisarasa_test:disposable-test-only@127.0.0.1:${TEST_DB_HOST_PORT:-55433}/sisarasa_test}"
docker compose -p sisarasa-academic-test -f compose.test.yaml up -d --wait
(cd backend && npm ci && npm run typecheck && npm test)
(cd android-app && flutter pub get && flutter analyze && flutter test)
