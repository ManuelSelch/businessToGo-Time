#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home"
export HOME="$tmp/home" PATH="$tmp/bin:$PATH" TEST_LOG="$tmp/commands"

cat > "$tmp/bin/xcodebuild" <<'MOCK'
#!/bin/bash
printf 'build\n' >> "$TEST_LOG"
for ((i=1; i<=$#; i++)); do
    if [[ "${!i}" == -destination ]]; then j=$((i+1)); printf '%s\n' "${!j}" >> "$TEST_LOG"; fi
    if [[ "${!i}" == -derivedDataPath ]]; then j=$((i+1)); derived="${!j}"; fi
done
if [[ "${FAIL_BUILD:-}" == 1 ]]; then exit 1; fi
mkdir -p "$derived/Build/Products/Debug-iphoneos/businessToGo.app"
MOCK
cat > "$tmp/bin/xcrun" <<'MOCK'
#!/bin/bash
printf 'install: %s\n' "$*" >> "$TEST_LOG"
MOCK
chmod +x "$tmp/bin/xcodebuild" "$tmp/bin/xcrun"

(cd / && bash "$root/scripts/install-iphone.sh")
grep -Fx 'platform=iOS,name=iPhone Manuel' "$TEST_LOG" >/dev/null
grep -F 'install: devicectl device install app --device iPhone Manuel ' "$TEST_LOG" >/dev/null

: > "$TEST_LOG"
if FAIL_BUILD=1 bash "$root/scripts/install-iphone.sh"; then
    echo 'Expected build failure' >&2
    exit 1
fi
if grep -q '^install:' "$TEST_LOG"; then
    echo 'Installation must not run after a failed build' >&2
    exit 1
fi

echo 'Install script tests passed.'
