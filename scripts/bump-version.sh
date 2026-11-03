#!/usr/bin/env bash
# Usage: bump-version.sh patch|minor|major. Writes the next version to the plist and prints it.
set -euo pipefail
cd "$(dirname "$0")/.."

kind=${1:?patch, minor or major}
plist=Support/Info.plist
current=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")
if ! [[ "$current" =~ ^([0-9]+)\.([0-9]+)(\.([0-9]+))?$ ]]; then
    echo "Unexpected version '$current' in $plist" >&2
    exit 1
fi
major=${BASH_REMATCH[1]} minor=${BASH_REMATCH[2]} patch=${BASH_REMATCH[4]:-0}

case "$kind" in
    patch) patch=$((patch + 1)) ;;
    minor) minor=$((minor + 1)) patch=0 ;;
    major) major=$((major + 1)) minor=0 patch=0 ;;
    *) echo "Unknown bump '$kind', expected patch, minor or major" >&2; exit 1 ;;
esac

next="$major.$minor.$patch"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $next" -c "Set :CFBundleVersion $next" "$plist"
echo "$next"
