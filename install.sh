#!/bin/bash
set -euo pipefail

REPO="3000-2/pounce"
APP="/Applications/Pounce.app"
# latest/download avoids the GitHub API and its anonymous rate limit.
URL="https://github.com/$REPO/releases/latest/download/Pounce.zip"

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "Pounce는 현재 Apple Silicon(arm64) 전용입니다." >&2
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Pounce 최신 버전 다운로드 중…"
curl -fsSL "$URL" -o "$TMP/pounce.zip"
ditto -x -k "$TMP/pounce.zip" "$TMP"

pkill -x Pounce 2>/dev/null || true
rm -rf "$APP"
ditto "$TMP/Pounce.app" "$APP"
# curl은 quarantine을 붙이지 않지만, 혹시 모를 잔여 속성까지 정리한다.
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

VERSION=$(defaults read "$APP/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "?")
echo "설치 완료: Pounce $VERSION → $APP"
open "$APP"
echo
echo "처음 설치했다면: 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서"
echo "Pounce를 켠 뒤 앱을 다시 실행하세요."
