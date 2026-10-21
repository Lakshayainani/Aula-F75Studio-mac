# Publishing on GitHub

This source folder is prepared as its own Git repository. Review it before
publishing. The private investigation workspace and its binaries/captures are
not part of this repository. MIT is included as a proposed source license;
review the license before publishing.

## Upload source and release files

1. Create an empty GitHub repository named, for example, `F75Studio`.
2. In this folder, commit and push the source:

   ```sh
   git add .
   git commit -m "Release F75 Studio 0.3.0"
   git branch -M main
   git remote add origin https://github.com/YOUR-USERNAME/F75Studio.git
   git push -u origin main
   ```

3. On GitHub, choose **Releases → Draft a new release**. Create tag `v0.3.0`
   targeting `main`; use the title **F75 Studio 0.3.0**.
4. Paste `RELEASE_NOTES.md`, attach the three archives and `SHA256SUMS.txt`
   from `release/`, then publish when ready. Source ZIP/TAR downloads generated
   automatically by GitHub are also available after tagging.

The included workflow builds/tests packages but does not publish releases.
Binaries and local build products are ignored by Git; attach them to Releases.

## Developer ID signing and notarization

No valid Apple signing identity was available when these packages were prepared.
The provided artifacts are ad-hoc signed and not notarized.

With a Developer ID Application identity installed, rebuild using:

```sh
SIGN_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' scripts/package-release.sh
```

Move the existing `release/` output aside first. The build script enables hardened
runtime and timestamping when a signing identity is supplied. Follow Apple's
[notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
to configure a Keychain credential profile, then submit the DMG:

```sh
xcrun notarytool submit release/F75Studio-0.3.0.dmg --keychain-profile F75StudioNotary --wait
xcrun stapler staple release/F75Studio-0.3.0.dmg
```

Verify the accepted result before publishing. Stapling changes the DMG, so
regenerate its checksum. The app ZIP must be notarized separately if distributed
as well; the source ZIP needs no notarization. This notarization path has not been
run because the required certificate/account are unavailable.

Test downloaded release files on a separate Mac before recommending them widely,
especially on Intel hardware or older macOS versions. Local build/launch success
is not a Gatekeeper/notarization result.
