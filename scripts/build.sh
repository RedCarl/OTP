#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
DEST="${1:-platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5}"
xcodegen generate >/dev/null
xcodebuild -project OTP.xcodeproj -scheme OTP -destination "$DEST" build