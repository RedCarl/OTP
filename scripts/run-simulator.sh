#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE="${1:-iPhone 16 Pro}"
DEST="platform=iOS Simulator,name=$DEVICE"
xcodegen generate >/dev/null
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator
xcodebuild -project OTP.xcodeproj -scheme OTP -destination "$DEST" build >/dev/null
APP_PATH="$(xcodebuild -project OTP.xcodeproj -scheme OTP -destination "$DEST" -showBuildSettings 2>/dev/null | awk -F'= ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}')/OTP.app"
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.redcarl.otp