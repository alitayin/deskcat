#!/bin/zsh
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: ./import_action_4x4.sh <sprite-sheet.png> <action> [cells]"
  echo "Actions: walk-right, walk-left, sleep, idle, tail, groom"
  echo "Cells: optional comma-separated 1-based 4x4 cell indexes, e.g. 1,2,5,6,9,10"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT_PATH="$1"
ACTION="$2"
SELECTED_CELLS="${3:-}"
OUTPUT_DIR="$ROOT_DIR/assets/pet"
CHECK_DIR="$ROOT_DIR/build/frame-checks/$ACTION"
STAGING_DIR="$ROOT_DIR/build/frame-import-staging/$ACTION"

case "$ACTION" in
  walk-right|walk-left)
    FRAME_COUNT=16
    ;;
  sleep)
    FRAME_COUNT=4
    ;;
  groom)
    FRAME_COUNT=4
    ;;
  idle|tail)
    FRAME_COUNT=6
    ;;
  *)
    echo "Unsupported action: $ACTION"
    echo "Actions: walk-right, walk-left, sleep, idle, tail, groom"
    exit 1
    ;;
esac

selected_cells=()
if [[ -n "$SELECTED_CELLS" ]]; then
  IFS=',' read -rA selected_cells <<< "$SELECTED_CELLS"
else
  for index in $(seq 1 "$FRAME_COUNT"); do
    selected_cells+=("$index")
  done
fi

if (( ${#selected_cells[@]} != FRAME_COUNT )); then
  echo "$ACTION requires $FRAME_COUNT selected cells, got ${#selected_cells[@]}."
  exit 1
fi

typeset -A cell_to_frame
for frame in $(seq 1 "$FRAME_COUNT"); do
  cell="${selected_cells[$frame]}"
  if ! [[ "$cell" =~ '^[0-9]+$' ]] || (( cell < 1 || cell > 16 )); then
    echo "Invalid cell index for $ACTION frame $frame: $cell"
    exit 1
  fi
  if [[ -n "${cell_to_frame[$cell]:-}" ]]; then
    echo "Duplicate selected cell for $ACTION: $cell"
    exit 1
  fi
  cell_to_frame[$cell]="$frame"
done

names=()
for index in {1..16}; do
  if [[ -n "${cell_to_frame[$index]:-}" ]]; then
    names+=("$ACTION-${cell_to_frame[$index]}")
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
  --contact-sheet "$CHECK_DIR/contact-sheet.png" \
  "$INPUT_PATH" "$STAGING_DIR" 4 4 "${names[@]}"

find "$OUTPUT_DIR" -maxdepth 1 -type f -name "$ACTION-*.png" -delete
find "$STAGING_DIR" -maxdepth 1 -type f -name "$ACTION-*.png" -exec cp {} "$OUTPUT_DIR/" \;

echo "Imported $ACTION into $OUTPUT_DIR"
echo "Check sheet: $CHECK_DIR/contact-sheet.png"
