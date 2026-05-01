#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$ROOT_DIR/build.sh"
open "$ROOT_DIR/build/Billy.app"
