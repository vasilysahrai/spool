#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Spool"
BUNDLE_ID="com.vasilysahrai.spool"
BIN_NAME="Spool"

echo "==> swift build -c release"
swift build -c release

BIN_PATH=".build/release/$BIN_NAME"
APP_DIR="$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"

echo "==> assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RES"
cp "$BIN_PATH" "$MACOS/$BIN_NAME"
chmod +x "$MACOS/$BIN_NAME"

cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>$BIN_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHumanReadableCopyright</key><string>MIT License · vasilysahrai</string>
</dict>
</plist>
EOF

echo "==> ad-hoc signing"
codesign --sign - --force --timestamp=none "$APP_DIR" >/dev/null 2>&1 || true

echo "==> done · $APP_DIR"
echo
echo "First launch:"
echo "  open $APP_DIR"
echo "Then grant Accessibility in System Settings > Privacy & Security."
