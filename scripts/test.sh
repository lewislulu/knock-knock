#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_DIR/.build"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/ModuleCache"
export SWIFT_MODULECACHE_PATH="$PROJECT_DIR/.build/ModuleCache"
swiftc "$PROJECT_DIR/Sources/ReminderPolicy.swift" "$PROJECT_DIR/Tests/ReminderPolicyTests.swift" -o "$PROJECT_DIR/.build/ReminderPolicyTests"
"$PROJECT_DIR/.build/ReminderPolicyTests"
python3 "$PROJECT_DIR/Tests/test_resources.py"
swiftc "$PROJECT_DIR/Sources/DesignPreferences.swift" "$PROJECT_DIR/Sources/PixelArt.swift" \
  "$PROJECT_DIR/Tests/NativeResourceTests.swift" -o "$PROJECT_DIR/.build/NativeResourceTests" -framework AppKit -framework SwiftUI
"$PROJECT_DIR/.build/NativeResourceTests" "$PROJECT_DIR/knock-knock.app"
