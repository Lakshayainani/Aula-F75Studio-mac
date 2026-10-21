# F75 Studio

A native macOS companion for the supported **wired AULA F75, model CD**.
Independent community software; not affiliated with or endorsed by AULA.

## Install

Download the DMG from this repository's **Releases**, open it, and drag **F75 Studio**
to **Applications**. Eject the DMG and open the installed app. A ZIP of the same
app is available as an alternative.

Connect the keyboard by USB in wired mode. Enable **F75 Studio** in
**System Settings → Privacy & Security → Input Monitoring**, then quit/reopen
and click **Connect**. No keystroke recorder or event tap is registered.

**Requirements:** macOS 13 or later. Release builds contain Apple Silicon and
Intel code. Intel and older macOS versions have not been runtime-tested.

**Signing:** community releases built without a Developer ID certificate are
ad-hoc signed and not notarized. macOS may block the first launch; review
[Apple's instructions](https://support.apple.com/102445) before choosing whether
to open an app from an unidentified developer. See [installation notes](docs/INSTALL.txt).

## Features

- Lighting effects, brightness, speed, preset colors, and rainbow.
- Key-to-key mapping with protected Fn.
- Manual keyboard/modifier macros with press/release events and delays.
- Persistent macro library: save, edit, rename, duplicate, remove, and JSON import/export.
- On-keyboard macro list with main-layer assignments and existing-record editing.
- Menu bar controls and optional launch at login, configured in Settings.
- Automatic backups before device writes, JSON export/import, and readback checks.
- Firmware inspection only. **Firmware flashing is disabled.**

Removing a saved library copy does not remove its onboard record. Updating an
onboard record affects every key/layer using it. Unsupported mouse/movement
macros are preserved, with editing unavailable. Export a backup before changing
settings. Local data is in `~/Library/Application Support/F75Studio`.

## Supported hardware and limits

USB `258A:010C`, configuration usage page `1`, usage `128`, 520-byte feature
reports, and exact model identifier `03 00 00 00 00 CD`. Matching USB IDs alone
are insufficient. Other revisions are rejected when their identity differs;
only one model-CD keyboard has been hardware-tested.

Bluetooth/2.4 GHz configuration, separate Fn-layer editing, arbitrary per-key
RGB painting, and firmware flashing are unavailable. Some effects retain numeric
names because the supplied resources lacked names. Readback checks confirm stored
configuration; they do not prove every lighting animation or macro behavior.

The existing updater expects a different USB interface than the tested keyboard
exposes. No bootloader-entry, erase, firmware-write, or reset transport is included.

## Build and test

Install Xcode Command Line Tools (`xcode-select --install`) or Xcode, with Swift
5.9+ and a macOS SDK. No third-party runtime dependencies are required.

```sh
scripts/test.sh
scripts/build-app.sh
```

The app is created in `dist/F75 Studio.app`. The build script compiles both
`arm64` and `x86_64` by default and combines them into a universal app.
For a host-only build, use `ARCHS=arm64 scripts/build-app.sh` or
`ARCHS=x86_64 scripts/build-app.sh`.

Tests use **synthetic fixtures**, require no keyboard, and send no device reports.
The application protocol was reconstructed from static Windows-driver analysis
and checked against physical configuration reads/writes. Proprietary driver files,
firmware, raw decompiler output, and personal hardware captures are excluded.
See [protocol notes](docs/PROTOCOL.md).

The optional CLI can be built with `swift build --disable-sandbox --product f75ctl`.
`f75ctl list` enumerates devices; `read output.json` exports a snapshot.
Commands starting with `verify-` perform real temporary writes and restoration;
use them only on a supported keyboard with a saved backup. They are not run by CI.

## Package a release

From a Git checkout (or after `git add .` for a new repository):

```sh
scripts/package-release.sh
```

This builds the app and creates a DMG, app ZIP, source ZIP, checksums, and release
notes under `release/`. Existing release files are not silently overwritten.
The source ZIP includes only Git-tracked/staged files. The GitHub Actions workflow
runs offline tests and uploads the same package as a workflow artifact; it does
not automatically publish a GitHub release.

See [publishing instructions](docs/PUBLISHING.md) for GitHub uploads and optional
Developer ID signing/notarization.

## License

MIT for this application's source; see [LICENSE](LICENSE). No OEM software or
firmware is included. AULA and macOS product names belong to their respective owners.
