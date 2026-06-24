#!/usr/bin/env bash
# Build Snapper and assemble a runnable macOS .app bundle.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
APP_NAME="Snapper"
EXEC_NAME="Snapper"
BUNDLE_ID="net.kinetix.Snapper"

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"
APP_DIR="$ROOT/build/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"

echo "==> assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RES"

cp "$BIN_PATH/$EXEC_NAME" "$MACOS/$EXEC_NAME"
cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"

# Copy the SwiftPM-generated resource bundle, if present.
if [ -d "$BIN_PATH/${EXEC_NAME}_${EXEC_NAME}.bundle" ]; then
    cp -R "$BIN_PATH/${EXEC_NAME}_${EXEC_NAME}.bundle" "$RES/"
fi

# Ad-hoc codesign so Keychain / network entitlements behave on launch.
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo "==> built: $APP_DIR"
