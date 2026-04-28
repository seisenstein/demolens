#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/DemoLens.app"
INSTALL_DIR="/Applications/DemoLens.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

"$ROOT_DIR/scripts/build-app.sh" >/dev/null

osascript -e 'tell application "DemoLens" to quit' >/dev/null 2>&1 || true
sleep 1

rm -rf "$INSTALL_DIR"
cp -R "$APP_DIR" "$INSTALL_DIR"

if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$INSTALL_DIR" >/dev/null 2>&1 || true
fi

if ! defaults read com.apple.dock persistent-apps 2>/dev/null | grep -q "/Applications/DemoLens.app"; then
  defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/DemoLens.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict><key>tile-type</key><string>file-tile</string></dict>'
  killall Dock >/dev/null 2>&1 || true
fi

open "$INSTALL_DIR"

echo "$INSTALL_DIR"
