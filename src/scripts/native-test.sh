#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
export PATH="${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools:$PATH"
serial=${ANDROID_SERIAL:-emulator-5580}
target=${1:?integration_test file relative to android-app is required}
name=$(basename "$target" .dart)
native_origin=${TEST_API_BASE:-http://10.0.2.2:3100}
dart_defines=$(python3 - "$native_origin" <<'PYCODE'
import base64,sys
print(base64.b64encode(('TEST_API_BASE='+sys.argv[1]).encode()).decode())
PYCODE
)
mkdir -p "$root/.superpowers" "$root/artifacts/screenshots"
cd "$root/android-app"
# Flutter prepares the ignored Gradle wrapper and SDK configuration on a fresh clone.
flutter build apk --debug --target "$target" --target-platform android-x64 --dart-define="TEST_API_BASE=$native_origin" > "$root/.superpowers/native-$name-prepare.log" 2>&1
cd android
ANDROID_SERIAL="$serial" ./gradlew app:assembleDebug app:assembleDebugAndroidTest \
  -Ptarget="$root/android-app/$target" -Ptarget-platform=android-x64 -Pdart-defines="$dart_defines" > "$root/.superpowers/native-$name-build.log" 2>&1
adb -s "$serial" install -r ../build/app/outputs/apk/debug/app-debug.apk > /dev/null
adb -s "$serial" install -r ../build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk > /dev/null
adb -s "$serial" shell am force-stop id.sisarasa.sisarasa_app
if [[ "$name" == notification_denied_test ]]; then
  adb -s "$serial" shell pm revoke id.sisarasa.sisarasa_app android.permission.POST_NOTIFICATIONS || true
  adb -s "$serial" shell pm set-permission-flags id.sisarasa.sisarasa_app android.permission.POST_NOTIFICATIONS user-set user-fixed
  trap 'adb -s "$serial" shell pm clear-permission-flags id.sisarasa.sisarasa_app android.permission.POST_NOTIFICATIONS user-set user-fixed >/dev/null' EXIT
fi
if [[ "$name" == notification_timeout_test ]]; then
  original=$(adb -s "$serial" shell device_config get activity_manager data_sync_fgs_timeout_duration | tr -d '\r')
  adb -s "$serial" shell device_config put activity_manager data_sync_fgs_timeout_duration 5000
  adb -s "$serial" shell pm grant id.sisarasa.sisarasa_app android.permission.POST_NOTIFICATIONS
  cleanup_timeout(){
    adb -s "$serial" shell input keyevent KEYCODE_WAKEUP
    if [[ "$original" == null ]]; then adb -s "$serial" shell device_config delete activity_manager data_sync_fgs_timeout_duration >/dev/null
    else adb -s "$serial" shell device_config put activity_manager data_sync_fgs_timeout_duration "$original"; fi
  }
  trap cleanup_timeout EXIT
fi
adb -s "$serial" logcat -c
adb -s "$serial" shell am instrument -w id.sisarasa.sisarasa_app.test/androidx.test.runner.AndroidJUnitRunner > "$root/.superpowers/native-$name.log" 2>&1 &
pid=$!
captured_ticket=false
captured_offline=false
backgrounded=false
while kill -0 "$pid" 2>/dev/null; do
  logs=$(adb -s "$serial" logcat -d -s flutter:I 2>/dev/null || true)
  if ! $captured_ticket && [[ "$logs" == *NATIVE_TICKET_READY* ]]; then
    adb -s "$serial" exec-out screencap -p > "$root/artifacts/screenshots/native-paid-ticket.png"
    captured_ticket=true
  fi
  if ! $captured_offline && [[ "$logs" == *NATIVE_OFFLINE_READY* ]]; then
    adb -s "$serial" exec-out screencap -p > "$root/artifacts/screenshots/native-process-offline.png"
    captured_offline=true
  fi
  if ! $backgrounded && [[ "$logs" == *NATIVE_MONITOR_READY* ]]; then
    adb -s "$serial" shell input keyevent KEYCODE_HOME
    adb -s "$serial" shell input keyevent KEYCODE_SLEEP
    backgrounded=true
  fi
  sleep .3
done
wait "$pid"
cat "$root/.superpowers/native-$name.log"
grep -q 'OK (' "$root/.superpowers/native-$name.log"
cp "$root/.superpowers/native-$name.log" "$root/artifacts/native-$name.txt"
