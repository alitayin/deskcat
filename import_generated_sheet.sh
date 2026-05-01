#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: ./import_generated_sheet.sh <sprite-sheet.png>"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$ROOT_DIR/assets/pet"

mkdir -p "$OUTPUT_DIR"
mkdir -p /tmp/swift-home /tmp/swift-module-cache /tmp/clang-module-cache
HOME=/tmp/swift-home \
SWIFT_MODULECACHE_PATH=/tmp/swift-module-cache \
CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
swift "$ROOT_DIR/scripts/slice_sprite_sheet.swift" "$1" "$OUTPUT_DIR"
echo "Imported assets into $OUTPUT_DIR"
