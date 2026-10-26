#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="${PRISMBAR_BUILD_DIR:-$HOME/Library/Caches/PrismBar/build}"
mkdir -p "$BUILD/ModuleCache"
xcrun swiftc -swift-version 5 -module-cache-path "$BUILD/ModuleCache" \
  "$ROOT/Sources/Core.swift" "$ROOT/Tests/CoreTests.swift" -o "$BUILD/CoreTests"
"$BUILD/CoreTests"
