#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
device='iPhone Manuel'
worktree_hash="$(printf '%s' "$root" | shasum -a 256 | cut -c 1-16)"
derived_data="$HOME/Library/Caches/businessToGoTime-device-build/$worktree_hash"
app="$derived_data/Build/Products/Release-iphoneos/businessToGoTime.app"

echo "Building this worktree for $device: $root"
echo 'Installing may replace the existing app with the same bundle identifier.'
xcodebuild build \
    -project "$root/businessToGoTime.xcodeproj" \
    -scheme businessToGoTime \
    -configuration Release \
    -destination "platform=iOS,name=$device" \
    -derivedDataPath "$derived_data" \
    -allowProvisioningUpdates

if [[ ! -d "$app" ]]; then
    echo "Build succeeded but the app bundle was not found: $app" >&2
    exit 1
fi

xcrun devicectl device install app --device "$device" "$app"
echo "Installed on $device. Unlock the phone and open businessToGo Time."
