#!/bin/bash
# Builds build/yathing.app.
# 서명: 빌드마다 권한(손쉬운 사용/입력 모니터링)이 초기화되지 않도록 고정 인증서를 쓴다.
# SIGN_IDENTITY 환경변수로 지정하지 않으면 첫 번째 코드서명 인증서를, 없으면 ad-hoc(+고정 identifier)을 쓴다.
set -euo pipefail
cd "$(dirname "$0")/.."
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
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk 'NR==1 {print $2}')}"
if [ -n "$IDENTITY" ]; then
  codesign --force --sign "$IDENTITY" "$APP"
else
  codesign --force --sign - -r='designated => identifier "com.sasca37.yathing"' "$APP"
fi
echo "Built $APP"
