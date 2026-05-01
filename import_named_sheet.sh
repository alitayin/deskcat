#!/bin/zsh
set -euo pipefail

if [[ $# -lt 5 ]]; then
  echo "Usage: ./import_named_sheet.sh <sprite-sheet.png> <cols> <rows> <name1> ... <nameN>"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$ROOT_DIR/assets/pet"
CHECK_DIR="$ROOT_DIR/build/frame-checks"
STAGING_DIR="$ROOT_DIR/build/frame-import-staging"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
mkdir -p "$CHECK_DIR"
mkdir -p /tmp/swift-home /tmp/swift-module-cache /tmp/clang-module-cache
HOME=/tmp/swift-home \
SWIFT_MODULECACHE_PATH=/tmp/swift-module-cache \
CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
swift "$ROOT_DIR/scripts/slice_named_sprite_sheet.swift" \
  --strict-pet-counts \
  --max-anchor-drift 10 \
  --min-edge-padding 8 \
  --max-scale-drift 0.18 \
  --max-area-drift 0.25 \
  --min-largest-component-ratio 0.92 \
  --contact-sheet "$CHECK_DIR/contact-sheet.png" \
  --anchor-report "$CHECK_DIR/anchor-report.txt" \
  "$1" "$STAGING_DIR" "$2" "$3" "${@:4}"
rm -rf "$OUTPUT_DIR"
mv "$STAGING_DIR" "$OUTPUT_DIR"
echo "Imported assets into $OUTPUT_DIR"
echo "Check sheet: $CHECK_DIR/contact-sheet.png"
echo "Anchor report: $CHECK_DIR/anchor-report.txt"
