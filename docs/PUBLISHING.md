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
4. Paste `RELEASE_NOTES.md` and choose **Publish release**. The **Publish macOS
   downloads** workflow automatically tests, builds the universal app, and attaches
   the DMG, app ZIP, source ZIP, and `SHA256SUMS.txt` to that same release.
5. Wait for the workflow to succeed, then share the release page. Users download
   the `.dmg` directly from **Assets**, open it, and drag the app into Applications.

For future versions, update both version fields in `assets/Info.plist`, update
release notes, commit/push, and publish a matching `vX.Y.Z` tag. A mismatched tag
fails before packaging, preventing incorrectly named downloads.

For an existing release, use **Actions → Publish macOS downloads → Run workflow**
and enter its tag. The selected tag must contain the build/package scripts. The release workflow
can run from the default branch, so it can also package an older release tag. A manual run does not create or publish a release; create the
release first. Reruns replace the four generated download/checksum assets.

The workflow uses GitHub's built-in token with `contents: write` for its release
job. No personal access token or Apple account is needed for ad-hoc-signed builds.
The separate **Build macOS app** workflow still checks pushes and pull requests
and keeps workflow artifacts. Binaries remain ignored by Git.

The automatic downloads have the same ad-hoc signing/notarization limitations
as local packages. This workflow does not install a Developer ID certificate or
perform notarization. If GitHub immutable releases are enabled, build and upload
to a draft using the manual workflow before publishing; published immutable
release assets cannot be replaced.

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
