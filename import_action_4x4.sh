#!/bin/zsh
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: ./import_action_4x4.sh <sprite-sheet.png> <action>"
  echo "Actions: walk-right, walk-left, sleep, idle, tail, groom"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT_PATH="$1"
ACTION="$2"
OUTPUT_DIR="$ROOT_DIR/assets/pet"
CHECK_DIR="$ROOT_DIR/build/frame-checks/$ACTION"
STAGING_DIR="$ROOT_DIR/build/frame-import-staging/$ACTION"

case "$ACTION" in
  walk-right|walk-left)
    FRAME_COUNT=10
    ;;
  sleep)
    FRAME_COUNT=4
    ;;
  idle|tail|groom)
    FRAME_COUNT=6
    ;;
  *)
    echo "Unsupported action: $ACTION"
    echo "Actions: walk-right, walk-left, sleep, idle, tail, groom"
    exit 1
    ;;
esac

names=()
for index in {1..16}; do
  if (( index <= FRAME_COUNT )); then
    names+=("$ACTION-$index")
  else
    names+=("_skip-$index")
  fi
done

rm -rf "$STAGING_DIR" "$CHECK_DIR"
mkdir -p "$STAGING_DIR" "$CHECK_DIR" "$OUTPUT_DIR"
mkdir -p /tmp/swift-home /tmp/swift-module-cache /tmp/clang-module-cache

HOME=/tmp/swift-home \
SWIFT_MODULECACHE_PATH=/tmp/swift-module-cache \
CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
swift "$ROOT_DIR/scripts/slice_named_sprite_sheet.swift" \
  --strict-pet-counts \
  --contact-sheet "$CHECK_DIR/contact-sheet.png" \
  --anchor-report "$CHECK_DIR/anchor-report.txt" \
  "$INPUT_PATH" "$STAGING_DIR" 4 4 "${names[@]}"

find "$OUTPUT_DIR" -maxdepth 1 -type f -name "$ACTION-*.png" -delete
find "$STAGING_DIR" -maxdepth 1 -type f -name "$ACTION-*.png" -exec cp {} "$OUTPUT_DIR/" \;

echo "Imported $ACTION into $OUTPUT_DIR"
echo "Check sheet: $CHECK_DIR/contact-sheet.png"
echo "Anchor report: $CHECK_DIR/anchor-report.txt"
