#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
stage="$(mktemp -d "${TMPDIR:-/tmp}/f75-icon.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
mkdir "$stage/AppIcon.iconset"
for size in 16 32 128 256 512; do
    /usr/bin/sips -z "$size" "$size" assets/AppIcon.png --out "$stage/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    doubled=$((size * 2))
    /usr/bin/sips -z "$doubled" "$doubled" assets/AppIcon.png --out "$stage/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$stage/AppIcon.iconset" -o assets/AppIcon.icns
test -s assets/AppIcon.icns
