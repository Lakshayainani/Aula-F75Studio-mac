#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' assets/Info.plist)"
base="F75Studio-$version"
mkdir -p release
if [[ -e "release/$base.dmg" || -e "release/$base-source.zip" ]]; then
    echo 'This version is already packaged. Preserve or move its release files before rebuilding.' >&2
    exit 1
fi
scripts/build-app.sh
stage="$(mktemp -d "${TMPDIR:-/tmp}/f75-package.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
mkdir "$stage/image"
/usr/bin/ditto "dist/F75 Studio.app" "$stage/image/F75 Studio.app"
ln -s /Applications "$stage/image/Applications"
cp docs/INSTALL.txt "$stage/image/READ ME FIRST.txt"
/usr/bin/hdiutil create -volname 'F75 Studio' -srcfolder "$stage/image" -format UDZO -ov "release/$base.dmg"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "dist/F75 Studio.app" "release/$base-macOS.zip"
python3 - "$base" <<'PY'
import pathlib, subprocess, sys, zipfile
base = sys.argv[1]
files = subprocess.check_output(['git', 'ls-files', '-z']).decode().split('\0')
if not any(files):
    raise SystemExit('Stage the source files with git add before packaging source.')
with zipfile.ZipFile('release/' + base + '-source.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in files:
        if not name:
            continue
        path = pathlib.Path(name)
        if path.is_absolute() or '..' in path.parts or path.is_symlink() or not path.is_file():
            raise SystemExit('Unexpected tracked source path: ' + name)
        archive.write(path, arcname=base + '/' + name)
PY
cp RELEASE_NOTES.md release/RELEASE_NOTES.md
(cd release && shasum -a 256 "$base.dmg" "$base-macOS.zip" "$base-source.zip" > SHA256SUMS.txt)
echo "Release files: $(pwd)/release"
