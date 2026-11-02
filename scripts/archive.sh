#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/bundle.sh

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)
zip="build/IonizedBar-$version.zip"
rm -f "$zip"
ditto -c -k --keepParent build/IonizedBar.app "$zip"
echo "$zip"
shasum -a 256 "$zip"
