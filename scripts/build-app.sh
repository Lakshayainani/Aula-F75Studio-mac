#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
stage="$(mktemp -d "${TMPDIR:-/tmp}/f75-build.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
architectures=(${ARCHS:-arm64 x86_64})
binaries=()
for architecture in "${architectures[@]}"; do
    case "$architecture" in arm64|x86_64) ;; *) echo "Unsupported architecture: $architecture" >&2; exit 1;; esac
    triple="$architecture-apple-macosx13.0"
    swift build --disable-sandbox -c release --product F75Studio --triple "$triple"
    bin_dir="$(swift build --disable-sandbox -c release --show-bin-path --triple "$triple")"
    cp "$bin_dir/F75Studio" "$stage/F75Studio-$architecture"
    /usr/bin/lipo "$stage/F75Studio-$architecture" -verify_arch "$architecture"
    binaries+=("$stage/F75Studio-$architecture")
done
bundle="$stage/F75 Studio.app"
mkdir -p "$bundle/Contents/MacOS"
/usr/bin/lipo -create "${binaries[@]}" -output "$bundle/Contents/MacOS/F75Studio"
chmod 755 "$bundle/Contents/MacOS/F75Studio"
cp assets/Info.plist "$bundle/Contents/Info.plist"
/usr/bin/plutil -lint "$bundle/Contents/Info.plist"
identity="${SIGN_IDENTITY:--}"
if [[ "$identity" == "-" ]]; then
    /usr/bin/codesign --force --sign - "$bundle"
else
    /usr/bin/codesign --force --sign "$identity" --options runtime --timestamp "$bundle"
fi
/usr/bin/codesign --verify --strict --verbose=2 "$bundle"
mkdir -p dist
if [[ -e "dist/F75 Studio.app" ]]; then
    mv "dist/F75 Studio.app" "dist/F75 Studio.previous.$(date '+%Y%m%d-%H%M%S').app"
fi
mv "$bundle" "dist/F75 Studio.app"
/usr/bin/lipo -archs "dist/F75 Studio.app/Contents/MacOS/F75Studio"
echo 'Built: dist/F75 Studio.app'
