#!/bin/bash
set -euo pipefail

APP_NAME="SoundBar.app"
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/$APP_NAME"
DEST="/Applications/$APP_NAME"

if [ ! -d "$SRC" ]; then
    echo "Error: $APP_NAME not found next to install.sh (looked in $HERE)" >&2
    exit 1
fi

echo "SoundBar installer"
echo "------------------"
echo

echo "Removing quarantine attribute from $SRC..."
xattr -dr com.apple.quarantine "$SRC" || true

if [ -d "$DEST" ]; then
    printf "%s already exists. Replace it? [y/N] " "$DEST"
    read -r answer
    case "$answer" in
        y|Y|yes|YES)
            rm -rf "$DEST"
            cp -R "$SRC" "$DEST"
            echo "Replaced $DEST"
            ;;
        *)
            echo "Skipped /Applications install. Launching from $SRC."
            open "$SRC"
            echo "Done. You can close this window."
            exit 0
            ;;
    esac
else
    cp -R "$SRC" "$DEST"
    echo "Installed to $DEST"
fi

xattr -dr com.apple.quarantine "$DEST" || true
open "$DEST"
echo "Done. You can close this window."
