#!/bin/bash
# Builds IPTVManager as a real macOS .app bundle (needed for AVKit to work correctly)
# and opens it. Usage: Scripts/build-app.sh [debug|release]

set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"
EXECUTABLE_NAME="IPTVManager"
DISPLAY_NAME="kantarto IPTV"
BUNDLE_ID="com.iptvmanager.app"
APP_DIR="dist/${DISPLAY_NAME}.app"
SIGNING_IDENTITY="kantarto IPTV Local Signing"

echo "Building (${CONFIG})..."
swift build -c "$CONFIG"

BIN_PATH=".build/${CONFIG}/${EXECUTABLE_NAME}"
if [ ! -f "$BIN_PATH" ]; then
  # Some SPM layouts nest the product under out/Products
  BIN_PATH=".build/out/Products/$( [ "$CONFIG" = "release" ] && echo Release || echo Debug )/${EXECUTABLE_NAME}"
fi

echo "Packaging app bundle at ${APP_DIR}..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/${EXECUTABLE_NAME}"

if [ -f "AppIcon/AppIcon.icns" ]; then
  cp "AppIcon/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi
if [ -f "AppIcon/icon_1024.png" ]; then
  cp "AppIcon/icon_1024.png" "$APP_DIR/Contents/Resources/profile.png"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string></string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGNING_IDENTITY"; then
  echo "Signing (${SIGNING_IDENTITY})..."
  codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_DIR"
else
  echo "Signing (ad-hoc — run Scripts/setup-signing.sh once for a stable identity so Keychain stops re-prompting)..."
  codesign --force --deep --sign - "$APP_DIR"
fi

echo "Launching..."
open "$APP_DIR"
