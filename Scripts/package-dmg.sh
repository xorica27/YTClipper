#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="YTClipper"
APP_VERSION="0.1.0"
VOLUME_NAME="$APP_NAME $APP_VERSION"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$BUILD_DIR/release/$APP_NAME.app"
DMG_WORK_DIR="$BUILD_DIR/dmg"
DMG_STAGING_DIR="$DMG_WORK_DIR/staging"
RW_DMG="$DMG_WORK_DIR/$APP_NAME-$APP_VERSION-rw.dmg"
FINAL_DMG="$DMG_WORK_DIR/$APP_NAME-$APP_VERSION.dmg"
BACKGROUND_NAME="background.png"

cd "$ROOT_DIR"
"$ROOT_DIR/Scripts/package-app.sh"

rm -rf "$DMG_WORK_DIR"
mkdir -p "$DMG_STAGING_DIR/.background"

cp -R "$APP_DIR" "$DMG_STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"
swift "$ROOT_DIR/Scripts/generate-dmg-background.swift" "$DMG_STAGING_DIR/.background/$BACKGROUND_NAME"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_STAGING_DIR" \
  -fs HFS+ \
  -format UDRW \
  -size 180m \
  "$RW_DMG" >/dev/null

MOUNT_OUTPUT="$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen)"
DEVICE="$(echo "$MOUNT_OUTPUT" | awk '/Apple_HFS/ {print $1}')"
MOUNT_POINT="$(echo "$MOUNT_OUTPUT" | awk '/Apple_HFS/ {for (i=3; i<=NF; i++) {printf "%s%s", (i==3 ? "" : " "), $i}; print ""}')"

if [[ -z "$DEVICE" || -z "$MOUNT_POINT" ]]; then
  echo "Could not mount DMG for styling." >&2
  exit 1
fi

SetFile -a V "$MOUNT_POINT/.background"

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {100, 100, 780, 520}

    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 112
    set background picture of viewOptions to file ".background:$BACKGROUND_NAME"

    set position of item "$APP_NAME.app" of container window to {190, 220}
    set position of item "Applications" of container window to {500, 220}

    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$DEVICE" >/dev/null
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" >/dev/null

echo "Packaged: $FINAL_DMG"
