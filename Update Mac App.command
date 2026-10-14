#!/bin/bash
# Double-click this file to rebuild the game from this project folder and
# update the app in your Applications folder (~/Applications). It works the
# same in Supermarket Sim and Zupermarket Zimulator: the app name comes from
# project.godot. Your saved games and settings are not touched.
#
# Needs (one-time):
#   1. Godot 4.7 in /Applications or ~/Applications (godotengine.org/download)
#   2. Its export templates: open Godot, then Editor > Manage Export Templates
#      > Download and Install
#
# Tip: change the version in Godot (Project > Project Settings > Application >
# Config > Version) before updating, and the main menu will show it.

DEST="$HOME/Applications"
cd "$(dirname "$0")" || exit 1
APP_NAME=$(grep -m 1 '^config/name=' project.godot | cut -d '"' -f 2)
[ -n "$APP_NAME" ] || APP_NAME="Supermarket Sim"

fail() {
	echo ""
	echo "ERROR: $1"
	echo ""
	read -r -p "Press Return to close."
	exit 1
}

GODOT=""
for g in "/Applications/Godot.app" "$HOME/Applications/Godot.app" /Applications/Godot*.app "$HOME"/Applications/Godot*.app; do
	if [ -x "$g/Contents/MacOS/Godot" ]; then
		GODOT="$g/Contents/MacOS/Godot"
		break
	fi
done
[ -n "$GODOT" ] || fail "Couldn't find Godot. Download Godot 4.7 from godotengine.org and drag it into Applications."

VERSION=$("$GODOT" --version | head -n 1 | sed -E 's/\.(official|custom_build|mono).*//')
TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/$VERSION/macos.zip"
[ -f "$TEMPLATES" ] || fail "Godot $VERSION is missing its export templates. Open Godot and use Editor > Manage Export Templates > Download and Install, then try again."

if pgrep -xq "$APP_NAME"; then
	fail "$APP_NAME is running. Quit the game first (your progress saves when you quit), then try again."
fi

echo "Building $APP_NAME with Godot $VERSION..."
mkdir -p build/mac
rm -rf "build/mac/$APP_NAME.app" "build/mac/$APP_NAME.zip"
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . --export-release "macOS" "build/mac/$APP_NAME.zip" || fail "The build failed. Open the project in Godot to see what's wrong."
[ -f "build/mac/$APP_NAME.zip" ] || fail "The build didn't produce an app."
ditto -x -k "build/mac/$APP_NAME.zip" build/mac || fail "Couldn't unpack the build."

echo "Installing into $DEST..."
mkdir -p "$DEST"
rm -rf "$DEST/$APP_NAME.app"
mv "build/mac/$APP_NAME.app" "$DEST/" || fail "Couldn't copy the app into $DEST."

echo ""
echo "Done! $APP_NAME is updated. Starting it now..."
open "$DEST/$APP_NAME.app"
sleep 2
