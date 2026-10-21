# App artwork

`AppIcon.png` is the transparent master artwork, generated and edited with the built-in image-generation tool. The design prompt requested a dark graphite mechanical keycap with a restrained violet rim and MAC STUDIO on the lower lip. The edit used the user's supplied AULA reference to place its emblem above its lettering in white inside the keycap.

Regenerate the macOS icon from the master with `bash scripts/build-icon.sh`. The app build copies `AppIcon.icns` into the signed bundle; GitHub release builds use the same asset.

F75 Studio is an independent companion app and is not affiliated with AULA or Apple. Brand names and marks belong to their respective owners.
