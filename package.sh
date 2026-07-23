#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
APP_PATH="$SCRIPT_DIR/build/hope的html阅读器.app"
DMG_PATH="$SCRIPT_DIR/dist/hope-html-reader-1.2-macos.dmg"
STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/hope-html-reader-dmg.XXXXXX")
trap 'rm -rf "$STAGING_DIR"' EXIT

"$SCRIPT_DIR/build.sh" >/dev/null
mkdir -p "$SCRIPT_DIR/dist"
ditto "$APP_PATH" "$STAGING_DIR/hope的html阅读器.app"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -volname "hope的html阅读器" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH" >/dev/null

echo "$DMG_PATH"
