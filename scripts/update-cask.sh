#!/bin/bash
# Homebrew tap(sasca37/homebrew-tap)의 cask 버전과 sha256을 갱신해 푸시한다.
# GitHub 릴리스에 DMG를 올린 뒤에 실행한다.
# usage: VERSION=1.0.1 ./scripts/update-cask.sh
set -euo pipefail
cd "$(dirname "$0")/.."
: "${VERSION:?VERSION=1.0.1 처럼 버전을 지정하세요}"
TAP="${TAP:-sasca37/homebrew-tap}"
DMG="build/yathing-$VERSION.dmg"
[ -f "$DMG" ] || { echo "$DMG 가 없습니다. 먼저 release.sh를 실행하세요." >&2; exit 1; }

SHA="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
gh repo clone "$TAP" "$WORK" -- -q

CASK="$WORK/Casks/yathing.rb"
sed -i '' -E "s/^(  version \").*(\")/\1$VERSION\2/; s/^(  sha256 \").*(\")/\1$SHA\2/" "$CASK"

cd "$WORK"
git diff --quiet && { echo "이미 $VERSION 입니다."; exit 0; }
git commit -qam "chore: yathing $VERSION"
git push -q origin main
echo "cask 갱신 완료: $VERSION ($SHA)"
