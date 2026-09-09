#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_APP="$PROJECT_DIR/.build/KnockKnockVisualTests.app"
OUTPUT_DIR="${1:-$PROJECT_DIR/.build/previews}"
mkdir -p "$TEST_APP/Contents/MacOS"
cp "$PROJECT_DIR/Tests/VisualTestInfo.plist" "$TEST_APP/Contents/Info.plist"
python3 "$PROJECT_DIR/scripts/resources.py" "$TEST_APP/Contents/Resources"
swift -module-cache-path "$PROJECT_DIR/.build/ModuleCache" "$PROJECT_DIR/scripts/icon.swift" "$PROJECT_DIR/.build"
cp "$PROJECT_DIR/.build/AppIcon.iconset/icon_256x256.png" "$TEST_APP/Contents/Resources/BrandMark.png"
SOURCE_FILES=()
for SOURCE_FILE in "$PROJECT_DIR"/Sources/*.swift; do
    if [[ "$SOURCE_FILE" != */App.swift ]]; then SOURCE_FILES+=("$SOURCE_FILE"); fi
done
swiftc -module-cache-path "$PROJECT_DIR/.build/ModuleCache" "${SOURCE_FILES[@]}" \
  "$PROJECT_DIR/Tests/RenderPreviews.swift" -o "$TEST_APP/Contents/MacOS/VisualTests" \
  -framework AppKit -framework SwiftUI -framework EventKit -framework ServiceManagement
"$TEST_APP/Contents/MacOS/VisualTests" "$OUTPUT_DIR"
