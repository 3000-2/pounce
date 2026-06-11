#!/bin/bash
set -euo pipefail

REPO="3000-2/pounce"
APP="/Applications/Pounce.app"

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "Pounce는 현재 Apple Silicon(arm64) 전용입니다." >&2
  exit 1
fi

TAG=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | grep -m1 '"tag_name"' | cut -d'"' -f4)
VERSION="${TAG#v}"
URL="https://github.com/$REPO/releases/download/$TAG/Pounce-$VERSION.zip"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Pounce $TAG 다운로드 중…"
curl -fsSL "$URL" -o "$TMP/pounce.zip"
ditto -x -k "$TMP/pounce.zip" "$TMP"

pkill -x Pounce 2>/dev/null || true
rm -rf "$APP"
ditto "$TMP/Pounce.app" "$APP"
# curl은 quarantine을 붙이지 않지만, 혹시 모를 잔여 속성까지 정리한다.
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

echo "설치 완료: $APP"
open "$APP"
echo
echo "처음 설치했다면: 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서"
echo "Pounce를 켠 뒤 앱을 다시 실행하세요."
