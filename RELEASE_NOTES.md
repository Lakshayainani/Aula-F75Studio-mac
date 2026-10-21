# F75 Studio 0.3.1

Native macOS companion for the supported wired AULA F75 model CD.

- Onboard lighting effects, preset colors, brightness and speed.
- Key mapping with protected Fn and automatic backups/readback checks.
- Manual keyboard/modifier macros with delays and JSON import/export.
- Persistent macro library; edit, rename, duplicate, and remove saved copies.
- Read and update existing keyboard macro records without changing their indexes.
- Menu bar controls and optional launch at login.
- Firmware file inspection; firmware flashing remains disabled.

## New in 0.3.1

- AULA emblem and white lettering inside a violet keycap app icon.
- Matching logo in the app sidebar.
- Icon master artwork and a macOS icon generation script included with the source.

## Downloads

- `F75Studio-0.3.1.dmg`: drag-to-Applications disk image.
- `F75Studio-0.3.1-macOS.zip`: the same app as a ZIP.
- `F75Studio-0.3.1-source.zip`: source, tests, fixtures, and build scripts.
- `SHA256SUMS.txt`: checksums of the three archives.

The macOS app contains Apple Silicon and Intel slices and targets macOS 13+.
Intel and older macOS versions have not been runtime-tested. Hardware testing
was performed on one model-CD keyboard, not every product sold as F75.

This build is ad-hoc signed and not notarized. Follow the linked Apple guidance
in the installation notes if macOS blocks it. Input Monitoring is required for
HID configuration access. No keystroke recorder or event tap is registered.

Only original application source and synthetic test fixtures are included.
The OEM installer, driver, firmware images, decompiler dumps, personal macros,
and captured user configurations are not distributed.
