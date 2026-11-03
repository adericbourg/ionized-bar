#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

app=build/IonizedBar.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/IonizedBar" "$app/Contents/MacOS/"
cp Support/Info.plist "$app/Contents/"

# A stable identity keeps the Accessibility and Screen Recording grants across builds; ad-hoc ties them to one build.
identity="IonizedBar Signing"
if security find-identity -p codesigning | grep -q "\"$identity\""; then
    codesign --force --sign "$identity" "$app"
else
    echo "warning: no '$identity' identity in the keychain, signing ad-hoc" >&2
    codesign --force --sign - "$app"
fi
