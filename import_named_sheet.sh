#!/bin/zsh
set -euo pipefail

if [[ $# -lt 5 ]]; then
  echo "Usage: ./import_named_sheet.sh <sprite-sheet.png> <cols> <rows> <name1> ... <nameN>"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$ROOT_DIR/assets/pet"

mkdir -p "$OUTPUT_DIR"
mkdir -p /tmp/swift-home /tmp/swift-module-cache /tmp/clang-module-cache
HOME=/tmp/swift-home \
SWIFT_MODULECACHE_PATH=/tmp/swift-module-cache \
CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
swift "$ROOT_DIR/scripts/slice_named_sprite_sheet.swift" "$1" "$OUTPUT_DIR" "$2" "$3" "${@:4}"
echo "Imported assets into $OUTPUT_DIR"
