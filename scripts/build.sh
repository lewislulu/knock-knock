#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/knock-knock.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$PROJECT_DIR/.build"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/ModuleCache"
export SWIFT_MODULECACHE_PATH="$PROJECT_DIR/.build/ModuleCache"
swiftc -O -swift-version 5 -target arm64-apple-macosx14.0 \
  -file-prefix-map "$PROJECT_DIR=knock-knock" -debug-prefix-map "$PROJECT_DIR=knock-knock" \
  "$PROJECT_DIR"/Sources/*.swift -o "$APP_DIR/Contents/MacOS/KnockKnock" \
  -framework AppKit -framework SwiftUI -framework EventKit -framework ServiceManagement -framework Carbon
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
python3 "$PROJECT_DIR/scripts/resources.py" "$APP_DIR/Contents/Resources"
swift "$PROJECT_DIR/scripts/icon.swift" "$PROJECT_DIR/.build"
cp "$PROJECT_DIR/.build/AppIcon.iconset/icon_256x256.png" "$APP_DIR/Contents/Resources/BrandMark.png"
iconutil -c icns "$PROJECT_DIR/.build/AppIcon.iconset" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
strip -S "$APP_DIR/Contents/MacOS/KnockKnock"
codesign --force --sign - --identifier app.knockknock.mac "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
printf 'Built %s\n' "$APP_DIR"
