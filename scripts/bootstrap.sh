#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
echo "Open OTP.xcodeproj in Xcode."
