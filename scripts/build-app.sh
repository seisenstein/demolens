#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/DemoLens.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"

swift build -c release --product DemoLens
BIN_DIR="$(swift build -c release --show-bin-path)"
BINARY="$BIN_DIR/DemoLens"

if [[ ! -x "$BINARY" ]]; then
  echo "Built binary not found at $BINARY" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BINARY" "$MACOS_DIR/DemoLens"
chmod +x "$MACOS_DIR/DemoLens"

cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/DemoLens.entitlements" "$RESOURCES_DIR/DemoLens.entitlements"

if [[ -d "$ROOT_DIR/Resources/Fonts" ]]; then
  mkdir -p "$RESOURCES_DIR/Fonts"
  cp "$ROOT_DIR"/Resources/Fonts/* "$RESOURCES_DIR/Fonts/"
fi

if [[ -d "$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset" ]]; then
  mkdir -p "$RESOURCES_DIR/AppIcon.appiconset"
  cp "$ROOT_DIR"/Resources/Assets.xcassets/AppIcon.appiconset/*.png "$RESOURCES_DIR/AppIcon.appiconset/"

  ICONSET_DIR="$ROOT_DIR/build/DemoLens.iconset"
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"
  cp "$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset/16x16@1x.png" "$ICONSET_DIR/icon_16x16.png"
  cp "$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset/16x16@2x.png" "$ICONSET_DIR/icon_16x16@2x.png"
  cp "$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset/32x32@1x.png" "$ICONSET_DIR/icon_32x32.png"
  cp "$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset/32x32@2x.png" "$ICONSET_DIR/icon_32x32@2x.png"
  cp "$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset/128x128@1x.png" "$ICONSET_DIR/icon_128x128.png"
  cp "$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset/128x128@2x.png" "$ICONSET_DIR/icon_128x128@2x.png"
  cp "$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset/256x256@1x.png" "$ICONSET_DIR/icon_256x256.png"
  cp "$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset/256x256@2x.png" "$ICONSET_DIR/icon_256x256@2x.png"
  cp "$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset/512x512@1x.png" "$ICONSET_DIR/icon_512x512.png"
  cp "$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset/512x512@2x.png" "$ICONSET_DIR/icon_512x512@2x.png"

  if command -v iconutil >/dev/null 2>&1; then
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/DemoLens.icns"
  fi
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

echo "$APP_DIR"
