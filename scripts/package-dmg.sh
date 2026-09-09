#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/knock-knock.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist")
DMG_NAME="knock-knock-v${VERSION}-macos-arm64.dmg"
bash "$PROJECT_DIR/scripts/build.sh"
mkdir -p "$PROJECT_DIR/.build" "$PROJECT_DIR/dist"
STAGING_DIR=$(mktemp -d "$PROJECT_DIR/.build/dmg.XXXXXX")
trap 'rm -rf "$STAGING_DIR"' EXIT
ditto --norsrc --noextattr --noacl "$APP_DIR" "$STAGING_DIR/knock-knock.app"
ln -s /Applications "$STAGING_DIR/Applications"
cp "$PROJECT_DIR/LICENSE" "$STAGING_DIR/LICENSE"
cp "$PROJECT_DIR/docs/INSTALL.txt" "$STAGING_DIR/INSTALL.txt"
codesign --verify --deep --strict "$STAGING_DIR/knock-knock.app"
hdiutil create -volname knock-knock -srcfolder "$STAGING_DIR" -fs HFS+ \
  -format UDZO -imagekey zlib-level=9 -ov "$PROJECT_DIR/dist/$DMG_NAME"
hdiutil verify "$PROJECT_DIR/dist/$DMG_NAME"
cd "$PROJECT_DIR/dist"
shasum -a 256 "$DMG_NAME" > SHA256SUMS
printf 'Packaged %s\n' "$DMG_NAME"
