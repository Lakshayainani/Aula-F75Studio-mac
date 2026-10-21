# Protocol notes

These are reconstruction notes, not an official AULA protocol specification.
The implementation supports the exact model identifier `03 00 00 00 00 CD`.

The configuration HID interface uses numbered feature report 6. Reports are
520 bytes: an eight-byte header followed by up to 512 payload bytes. Header
bytes are report ID, command, subcommand, reserved zero, total page count,
zero-based page index, and fragment length LE16.

| Data | Read | Write | Payload |
|---|---|---|---|
| Model identity | 82, subcommand 1 | — | 6 bytes |
| Lighting | 84 | 04 | 128 bytes |
| Main-layer keys | 83 | 03 | 512 bytes |
| Macro bank | 85 | 05 | Up to 4096 bytes, paged |

Lighting and key payloads preserve their `5A A5` trailer. Key entries are four
bytes; the Fn matrix index 53 remains `[13,0,0,0]`. A fixed-repeat macro binding
is `[3,1,repeatCount,recordIndex]`.

The macro bank begins with N pairs of `(offset LE16, length LE16)`, followed by
contiguous records. The first record offset is `N*4`; indexes are zero-based and
shared by layers. Each record has a one-byte UTF-16LE name byte count, name bytes,
and four-byte events: flags/delay-high nibble, delay-middle, delay-low, HID usage.
Keyboard events use class 0; modifiers E0–E7 use class 1; bit 7 marks release.
Maximum delay is 20 bits. Existing unsupported records are preserved unchanged.
All-zero memory was observed on an empty tested bank; all-FF is also recognized
as empty but has not been observed on the tested device.

Changing one record rebuilds offsets but retains every record's index. Updates
compare the old record to reject stale edits, preserve other records, save a
full backup, and check returned storage before reporting success.

Firmware inspection handles Intel HEX and the exact separately supplied updater
by source/payload hashes. Its image is not included here. Matching USB IDs does
not prove image compatibility. Firmware flashing remains disabled because the
board revision, updater interfaces, and recovery path are not established.
