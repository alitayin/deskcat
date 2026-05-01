#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/Billy.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

mkdir -p /tmp/swift-home /tmp/swift-module-cache /tmp/clang-module-cache
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

if [[ -d "$ROOT_DIR/assets/pet" ]]; then
  mkdir -p "$RESOURCES_DIR/assets/pet"
  for pet_frame in "$ROOT_DIR"/assets/pet/*.png(N); do
    cp "$pet_frame" "$RESOURCES_DIR/assets/pet/"
  done
fi

if [[ -f "$ROOT_DIR/assets/app-icon.png" ]]; then
  ICONSET_DIR="$BUILD_DIR/Billy.iconset"
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"
  sips -z 16 16 "$ROOT_DIR/assets/app-icon.png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ROOT_DIR/assets/app-icon.png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ROOT_DIR/assets/app-icon.png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ROOT_DIR/assets/app-icon.png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ROOT_DIR/assets/app-icon.png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ROOT_DIR/assets/app-icon.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ROOT_DIR/assets/app-icon.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ROOT_DIR/assets/app-icon.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ROOT_DIR/assets/app-icon.png" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ROOT_DIR/assets/app-icon.png" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
  HOME=/tmp/swift-home \
  SWIFT_MODULECACHE_PATH=/tmp/swift-module-cache \
  CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
  swift "$ROOT_DIR/scripts/make_icns.swift" "$ICONSET_DIR" "$RESOURCES_DIR/BillyIcon.icns"
fi

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>Billy</string>
  <key>CFBundleIconFile</key>
  <string>BillyIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.alitayin.billy</string>
  <key>CFBundleDisplayName</key>
  <string>Billy</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Billy</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0-beta.1</string>
  <key>CFBundleVersion</key>
  <string>3</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.entertainment</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 alitayin. All rights reserved.</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

HOME=/tmp/swift-home \
SWIFT_MODULECACHE_PATH=/tmp/swift-module-cache \
CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
swiftc "$ROOT_DIR/CatBuddy.swift" -o "$MACOS_DIR/Billy" -framework Cocoa

xattr -cr "$APP_DIR" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR"

echo "Built: $APP_DIR"
