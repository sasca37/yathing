#!/bin/bash
# Builds build/yathing.app.
# 서명: 빌드마다 권한(손쉬운 사용/입력 모니터링)이 초기화되지 않도록 고정 인증서를 쓴다.
# SIGN_IDENTITY로 지정하지 않으면 Developer ID Application → 첫 번째 코드서명 인증서 → ad-hoc 순으로 고른다.
# 버전: VERSION=1.0.0 (기본 0.1.0). 빌드 번호는 커밋 수.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-0.1.0}"
BUILD="$(git rev-list --count HEAD)"
# 유니버설 (Apple Silicon + Intel). 출력 경로는 Xcode 버전마다 달라서 SwiftPM에게 묻는다.
ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"
APP=build/yathing.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN/MacForKeyset" "$APP/Contents/MacOS/MacForKeyset"
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns Resources/MenuBarIcon.png Resources/MenuBarIcon@2x.png "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.sasca37.yathing</string>
  <key>CFBundleName</key><string>yathing</string>
  <key>CFBundleDisplayName</key><string>yathing</string>
  <key>CFBundleExecutable</key><string>MacForKeyset</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 sasca37. MIT License.</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
IDS="$(security find-identity -v -p codesigning)"
IDENTITY="${SIGN_IDENTITY:-$(awk '/^ *[0-9]+\)/ && /Developer ID Application/ {print $2; exit}' <<<"$IDS")}"
IDENTITY="${IDENTITY:-$(awk '/^ *[0-9]+\)/ {print $2; exit}' <<<"$IDS")}"
if grep -q "$IDENTITY.*Developer ID Application" <<<"$IDS"; then
  # 공증 조건: hardened runtime + 보안 타임스탬프
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
elif [ -n "$IDENTITY" ]; then
  codesign --force --sign "$IDENTITY" "$APP"
else
  codesign --force --sign - -r='designated => identifier "com.sasca37.yathing"' "$APP"
fi
echo "Built $APP ($VERSION, build $BUILD)"
