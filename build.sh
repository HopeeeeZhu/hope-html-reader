#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
APP_DIR="$SCRIPT_DIR/build/hope的html阅读器.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/hope-html-reader.XXXXXX")
ICONSET_DIR="$TEMP_DIR/AppIcon.iconset"
ARM_BINARY="$TEMP_DIR/HTMLReader-arm64"
INTEL_BINARY="$TEMP_DIR/HTMLReader-x86_64"
trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"
cp "$SCRIPT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

for spec in \
  "16 icon_16x16.png" \
  "32 icon_16x16@2x.png" \
  "32 icon_32x32.png" \
  "64 icon_32x32@2x.png" \
  "128 icon_128x128.png" \
  "256 icon_128x128@2x.png" \
  "256 icon_256x256.png" \
  "512 icon_256x256@2x.png" \
  "512 icon_512x512.png" \
  "1024 icon_512x512@2x.png"; do
  size=${spec%% *}
  name=${spec#* }
  sips -z "$size" "$size" "$SCRIPT_DIR/AppIcon.png" --out "$ICONSET_DIR/$name" >/dev/null
done
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

xcrun swiftc "$SCRIPT_DIR/App.swift" -O -target arm64-apple-macos13.0 -framework AppKit -framework WebKit -o "$ARM_BINARY"
xcrun swiftc "$SCRIPT_DIR/App.swift" -O -target x86_64-apple-macos13.0 -framework AppKit -framework WebKit -o "$INTEL_BINARY"
lipo -create "$ARM_BINARY" "$INTEL_BINARY" -output "$MACOS_DIR/HTMLReader"
codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
