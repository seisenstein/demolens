#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/DemoLens.app"
INSTALL_DIR="/Applications/DemoLens.app"

"$ROOT_DIR/scripts/build-app.sh" >/dev/null

rm -rf "$INSTALL_DIR"
cp -R "$APP_DIR" "$INSTALL_DIR"
open "$INSTALL_DIR"

echo "$INSTALL_DIR"
