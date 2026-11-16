#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-docs/screenshot.png}"
mkdir -p "$(dirname "$OUT")"
xcrun simctl io booted screenshot "$OUT"
echo "saved $OUT"
