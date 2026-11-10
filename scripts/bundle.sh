#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

app=build/IonizedBar.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/IonizedBar" "$app/Contents/MacOS/"
cp Support/Info.plist "$app/Contents/"
/usr/libexec/PlistBuddy -c "Add :IonizedBarCommit string $(git rev-parse --short HEAD)" "$app/Contents/Info.plist"

# A stable identity keeps the Accessibility and Screen Recording grants across builds; ad-hoc ties them to one build.
identity="IonizedBar Signing"
if ! security find-identity -p codesigning | grep -q "\"$identity\""; then
    echo "warning: no '$identity' identity in the keychain, signing ad-hoc" >&2
    identity=-
fi
# Hardened runtime: without it any process can load code into the app (DYLD_INSERT_LIBRARIES) and use its grants.
# It blocks Apple events too, hence the entitlement for the restart and shutdown dialogs.
codesign --force --options runtime --entitlements Support/IonizedBar.entitlements --sign "$identity" "$app"
