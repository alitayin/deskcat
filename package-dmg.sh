#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/Billy.app"
DMG_ROOT="$BUILD_DIR/dmg-root"
DMG_PATH="$BUILD_DIR/Billy.dmg"

"$ROOT_DIR/build.sh"

rm -rf "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$DMG_ROOT"

cp -R "$APP_DIR" "$DMG_ROOT/Billy.app"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "Billy" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Packaged: $DMG_PATH"
