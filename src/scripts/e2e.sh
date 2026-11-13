#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
export TEST_DATABASE_URL="${TEST_DATABASE_URL:-postgres://sisarasa_test:disposable-test-only@127.0.0.1:${TEST_DB_HOST_PORT:-55433}/sisarasa_test}"
(cd "$root/backend" && npm run test:e2e)
"$root/scripts/health.sh"
"$root/scripts/native-test.sh" integration_test/marketplace_test.dart
"$root/scripts/native-test.sh" integration_test/process_recovery_test.dart
"$root/scripts/native-test.sh" integration_test/notification_denied_test.dart
"$root/scripts/native-test.sh" integration_test/notification_timeout_test.dart
"$root/scripts/native-test.sh" integration_test/notification_navigation_test.dart
"$root/scripts/native-test.sh" integration_test/offline_ticket_test.dart
