#!/usr/bin/env bash
# Build Snapper and assemble a runnable macOS .app bundle.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
APP_NAME="Snapper"
EXEC_NAME="Snapper"
BUNDLE_ID="au.com.athenanetworks.Snapper"

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

# App icon (Info.plist references CFBundleIconFile = AppIcon).
if [ -f "$ROOT/AppIcon.icns" ]; then
    cp "$ROOT/AppIcon.icns" "$RES/AppIcon.icns"
fi

# Copy the SwiftPM-generated resource bundle, if present.
if [ -d "$BIN_PATH/${EXEC_NAME}_${EXEC_NAME}.bundle" ]; then
    cp -R "$BIN_PATH/${EXEC_NAME}_${EXEC_NAME}.bundle" "$RES/"
fi

# ---- Code signing ----
# Signs with the Developer ID Application identity by default. Override with:
#   CODESIGN_IDENTITY="Apple Development: ... (TEAMID)" ./scripts/build.sh   # local dev
# Set HARDENED=1 for the hardened runtime + secure timestamp (required for notarization).
# Set NOTARIZE=1 (implies HARDENED) to submit to Apple's notary service and staple the
# ticket; requires NOTARY_PROFILE to name a stored notarytool keychain profile.
# Falls back to ad-hoc signing if the identity isn't in the keychain.
SIGN_IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Serenity Space Pty Ltd (4S7BG5A4XV)}"
ENTITLEMENTS="$ROOT/Snapper.entitlements"

[ "${NOTARIZE:-0}" = "1" ] && HARDENED=1

# SwiftPM's resource bundle is a plain resource directory (no Info.plist), so codesign
# can't sign it standalone — a single recursive (--deep) sign seals it correctly.
SIGN_FLAGS=(--force --deep)
[ -f "$ENTITLEMENTS" ] && SIGN_FLAGS+=(--entitlements "$ENTITLEMENTS")
if [ "${HARDENED:-0}" = "1" ]; then
    SIGN_FLAGS+=(--options runtime --timestamp)
fi

if security find-identity -v -p codesigning | grep -qF "$SIGN_IDENTITY"; then
    echo "==> codesigning with: $SIGN_IDENTITY"
    codesign "${SIGN_FLAGS[@]}" --sign "$SIGN_IDENTITY" "$APP_DIR"
    echo "==> verifying signature"
    codesign --verify --strict --verbose=2 "$APP_DIR"
    codesign -dvv "$APP_DIR" 2>&1 | grep -E "Authority=Apple Development|Authority=Developer ID|TeamIdentifier" | head -2
else
    echo "==> WARNING: identity '$SIGN_IDENTITY' not found in keychain — ad-hoc signing"
    codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true
fi

# ---- Notarization (opt-in) ----
if [ "${NOTARIZE:-0}" = "1" ]; then
    : "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a stored notarytool keychain profile (see 'xcrun notarytool store-credentials')}"
    ZIP="$ROOT/build/$APP_NAME.zip"
    echo "==> notarizing (profile: $NOTARY_PROFILE)"
    ditto -c -k --keepParent "$APP_DIR" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    echo "==> stapling ticket"
    xcrun stapler staple "$APP_DIR"
    xcrun stapler validate "$APP_DIR"
    spctl -a -vv "$APP_DIR" || true
    # Re-package the stapled app for distribution.
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP_DIR" "$ZIP"
    echo "==> notarized & stapled: $ZIP"
fi

echo "==> built: $APP_DIR"
