#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist
xcodebuild \
  -project MyApp.xcodeproj \
  -scheme MyApp \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  DEVELOPMENT_TEAM='' \
  build 2>&1 | tee dist/build.log

APP='build/Build/Products/Release-iphoneos/MyApp.app'
EXT="$APP/PlugIns/MyWidgetExtension.appex"
test -d "$APP"
test -d "$EXT"
# Assert that this is a device build containing the widget, not a simulator app.
/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Print NSExtension:NSExtensionPointIdentifier' "$EXT/Info.plist"
APP_BINARY=$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$APP/Info.plist")
xcrun lipo -verify_arch arm64 "$APP/$APP_BINARY"
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
mkdir -p "$STAGING/Payload"
ditto "$APP" "$STAGING/Payload/MyApp.app"
/usr/bin/ditto -c -k --keepParent "$STAGING/Payload" dist/GlassTest-unsigned.ipa
unzip -t dist/GlassTest-unsigned.ipa
