#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
DEST="${1:-platform=iOS Simulator,name=iPhone 18 Pro,OS=27.2}"
xcodegen generate >/dev/null
xcodebuild -project OTP.xcodeproj -scheme OTP -destination "$DEST" build