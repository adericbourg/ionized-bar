#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

app=build/IonizedBar.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/IonizedBar" "$app/Contents/MacOS/"
cp Support/Info.plist "$app/Contents/"
codesign --force --sign - "$app"
