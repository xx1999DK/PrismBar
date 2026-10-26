#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="${PRISMBAR_BUILD_DIR:-$HOME/Library/Caches/PrismBar/build}"
DIST="${PRISMBAR_DIST_DIR:-$ROOT/dist}"
ARCH="${PRISMBAR_ARCH:-$(uname -m)}"
case "$ARCH" in arm64|x86_64) ;; *) echo 'Unsupported architecture' >&2; exit 1;; esac
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/prismbar.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/PrismBar.app"
mkdir -p "$BUILD/ModuleCache" "$DIST" "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -O -whole-module-optimization -swift-version 5 -target "$ARCH-apple-macos13.0" \
  -module-cache-path "$BUILD/ModuleCache" -framework AppKit -framework SwiftUI -framework Carbon \
  -framework ApplicationServices -framework ServiceManagement "$ROOT"/Sources/*.swift -o "$APP/Contents/MacOS/PrismBar"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/"; fi
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
ditto -c -k --keepParent --norsrc "$APP" "$DIST/PrismBar-macOS-$ARCH.zip"
echo "Built: $DIST/PrismBar-macOS-$ARCH.zip"
