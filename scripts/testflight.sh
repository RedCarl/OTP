#!/usr/bin/env bash
# 归档并上传 OTP 到 TestFlight。
#
#   scripts/testflight.sh              # 用 project.yml 里的 CURRENT_PROJECT_VERSION
#   BUILD_NUMBER=14 scripts/testflight.sh
#
# 需要 App Store Connect Team API Key（默认读 ~/.appstoreconnect/private_keys）。
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="${TEAM_ID:-BCRZR3P4AP}"
KEY_DIR="${ASC_KEY_DIR:-$HOME/.appstoreconnect/private_keys}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$KEY_DIR/AuthKey_6SYYHDN6SJ.p8}"
ASC_KEY_ID="${ASC_KEY_ID:-6SYYHDN6SJ}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-$(cat "$KEY_DIR/issuer_id.txt" 2>/dev/null || true)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(grep -E '^\s*CURRENT_PROJECT_VERSION:' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')}"
MARKETING_VERSION="${MARKETING_VERSION:-$(grep -E '^\s*MARKETING_VERSION:' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')}"
WORK="${OTP_TF_WORK:-build}"
ARCHIVE="$WORK/OTP.xcarchive"

if [[ -z "$ASC_ISSUER_ID" ]]; then
  echo "缺少 ASC issuer id：$KEY_DIR/issuer_id.txt" >&2
  exit 2
fi

if [[ -d "$ARCHIVE" ]]; then
  PREV="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleVersion' "$ARCHIVE/Info.plist" 2>/dev/null || true)"
  if [[ -n "$PREV" ]]; then
    mv "$ARCHIVE" "$WORK/OTP-build$PREV.xcarchive"
    echo "==> 旧归档保留为 $WORK/OTP-build$PREV.xcarchive"
  fi
fi

AUTH_ARGS=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")

xcodegen generate >/dev/null

echo "==> 归档 OTP $MARKETING_VERSION ($BUILD_NUMBER)"
xcodebuild archive \
  -project OTP.xcodeproj -scheme OTP \
  -destination 'generic/platform=iOS' -configuration Release \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM_ID" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  "${AUTH_ARGS[@]}"

echo "==> 导出并上传到 TestFlight"
rm -rf "$WORK/upload"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$WORK/upload.plist" \
  -exportPath "$WORK/upload" \
  -allowProvisioningUpdates \
  "${AUTH_ARGS[@]}"

echo "==> 上传完成；App Store Connect → TestFlight 处理通常 5–30 分钟。"
