#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
device_id=${RUSH_RISK_SIMULATOR_ID:-}

cd "$repo_dir"
swift test --parallel

if [[ -z "$device_id" ]]; then
  echo "Core smoke tests passed. Set RUSH_RISK_SIMULATOR_ID to run 10 live simulator sessions."
  exit 0
fi

xcrun simctl boot "$device_id" 2>/dev/null || true
xcrun simctl bootstatus "$device_id" -b

xcodebuild \
  -project "Rush or Risk.xcodeproj" \
  -scheme "Rush or Risk" \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=$device_id" \
  CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath build/SmokeDerivedData \
  build

app_path="$repo_dir/build/SmokeDerivedData/Build/Products/Debug-iphonesimulator/Rush or Risk.app"
xcrun simctl install "$device_id" "$app_path"

for session_number in {1..10}; do
  xcrun simctl terminate "$device_id" com.APLDEVO.Rush-or-Risk 2>/dev/null || true
  launch_output=$(xcrun simctl launch "$device_id" com.APLDEVO.Rush-or-Risk -startGame -deterministicSmoke)
  app_pid=${launch_output##*: }
  sleep 4
  if ! ps -p "$app_pid" >/dev/null; then
    echo "Gameplay session $session_number failed (pid $app_pid exited)."
    exit 1
  fi
  echo "Gameplay session $session_number passed."
done

xcrun simctl terminate "$device_id" com.APLDEVO.Rush-or-Risk 2>/dev/null || true
echo "All 10 gameplay sessions passed."
