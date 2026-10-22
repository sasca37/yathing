#!/bin/bash
# 배포용 DMG를 만든다: 빌드 → DMG(앱 + 응용 프로그램 바로가기) → 서명 → 공증 → staple.
# usage: VERSION=1.0.0 ./scripts/release.sh
# 공증 자격 증명은 처음 한 번 저장해 둔다 (README "배포" 참고). 프로필 이름은 NOTARY_PROFILE (기본 yathing-notary).
set -euo pipefail
cd "$(dirname "$0")/.."
: "${VERSION:?VERSION=1.0.0 처럼 버전을 지정하세요}"
NOTARY_PROFILE="${NOTARY_PROFILE:-yathing-notary}"
APP=build/yathing.app
DMG="build/yathing-$VERSION.dmg"

VERSION="$VERSION" ./scripts/build-app.sh

# 공증은 Developer ID 서명만 받는다. 다른 인증서로 서명됐으면 여기서 멈춘다.
IDENTITY="$(codesign -dv --verbose=2 "$APP" 2>&1 | sed -n 's/^Authority=\(Developer ID Application: .*\)$/\1/p')"
if [ -z "$IDENTITY" ]; then
  echo "앱이 Developer ID Application 인증서로 서명되지 않았습니다. README '배포'의 인증서 준비를 확인하세요." >&2
  exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/yathing.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname yathing -srcfolder "$STAGE" -format UDZO -quiet "$DMG"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"

echo
echo "완료: $DMG"
shasum -a 256 "$DMG"  # Homebrew cask의 sha256
