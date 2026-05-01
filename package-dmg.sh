#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/Billy.app"
DMG_ROOT="$BUILD_DIR/dmg-root"
DMG_PATH="$BUILD_DIR/Billy.dmg"
RW_DMG_PATH="$BUILD_DIR/Billy-rw.dmg"

"$ROOT_DIR/build.sh"

rm -rf "$DMG_ROOT" "$DMG_PATH" "$RW_DMG_PATH"
mkdir -p "$DMG_ROOT"

for mounted_volume in /Volumes/Billy(N) /Volumes/Billy\ *(N); do
  hdiutil detach "$mounted_volume" >/dev/null 2>&1 || true
done

cp -R "$APP_DIR" "$DMG_ROOT/Billy.app"
ln -s /Applications "$DMG_ROOT/Applications"
cat > "$DMG_ROOT/README.txt" <<'README'
Billy 0.1.0-beta.1

这是未公证的小群测试版。macOS 首次打开时可能提示无法验证开发者。

安装：
1. 将 Billy.app 拖到 Applications。
2. 如果首次双击打不开，请右键点击 Billy.app，选择“打开”。
3. 确认安全提示后即可启动。
README

hdiutil create \
  -volname "Billy" \
  -srcfolder "$DMG_ROOT" \
  -format UDRW \
  -fs HFS+ \
  -ov \
  "$RW_DMG_PATH"

ATTACH_OUTPUT="$(hdiutil attach "$RW_DMG_PATH" \
  -readwrite \
  -noverify \
  -noautoopen)"
MOUNT_DIR="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/Apple_HFS/ {print substr($0, index($0, "/Volumes/")); exit}')"
if [[ -z "$MOUNT_DIR" || ! -d "$MOUNT_DIR" ]]; then
  echo "Failed to mount DMG for layout"
  printf '%s\n' "$ATTACH_OUTPUT"
  exit 1
fi

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "Billy"
    open
    delay 0.6
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {220, 160, 720, 460}
    set theViewOptions to icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 96
    set text size of theViewOptions to 12
    set position of item "Billy.app" of container window to {135, 135}
    set position of item "Applications" of container window to {365, 135}
    set position of item "README.txt" of container window to {250, 255}
    update without registering applications
    delay 0.6
    close
  end tell
end tell
APPLESCRIPT

if [[ ! -f "$MOUNT_DIR/.DS_Store" ]]; then
  echo "Finder layout was not written to $MOUNT_DIR/.DS_Store"
  hdiutil detach "$MOUNT_DIR" >/dev/null || true
  exit 1
fi

SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
bless --folder "$MOUNT_DIR" --openfolder "$MOUNT_DIR" 2>/dev/null || true
sync
hdiutil detach "$MOUNT_DIR" >/dev/null

hdiutil convert "$RW_DMG_PATH" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o \
  "$DMG_PATH"

rm -rf "$RW_DMG_PATH" "$DMG_ROOT"

echo "Packaged: $DMG_PATH"
