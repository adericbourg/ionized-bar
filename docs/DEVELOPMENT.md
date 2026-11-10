# Development

## Build

Command Line Tools are enough, Xcode is not needed.

```sh
./scripts/bundle.sh
open --stderr "$(tty)" build/IonizedBar.app
```

`bundle.sh` signs with the `IonizedBar Signing` identity when it is in the keychain, and ad-hoc otherwise (with a warning). An ad-hoc build loses the permissions on every rebuild. Both sign with the hardened runtime, so that no other process can load code into the app and use its permissions; `Support/IonizedBar.entitlements` holds the one exception the app needs, sending Apple events (the restart and shutdown dialogs).

Coming from an ad-hoc build, grant the permissions once more. If IonizedBar already shows ON but the bar stays empty, reset the grant, then grant it again:

```sh
tccutil reset Accessibility io.github.adericbourg.ionized-bar
```

## Checks

`swift run IonizedBarChecks` runs the pure-logic checks (no XCTest on Command Line Tools) and exits non-zero on failure.

## Releasing

Apple silicon only. `./scripts/archive.sh` builds the bundle and zips it into `build/IonizedBar-<version>.zip`, printing the path and its sha256 (for the cask). To release: run the Release workflow from the Actions tab on `main` and pick the part to increase: `patch`, `minor` (default) or `major`. It runs the checks, sets the next version in `Support/Info.plist` with `./scripts/bump-version.sh` (both `CFBundleShortVersionString` and `CFBundleVersion`), builds and signs the zip, then creates the GitHub release `v<version>` on a `chore: release v<version>` commit, and pushes that commit to `main` last. Up to there, nothing is left if a step fails: the push fails if `main` moved during the run, and the release and its tag are then deleted. Don't edit the version by hand. A second job then sets `version` and `sha256` in `Casks/ionized-bar.rb` of `adericbourg/homebrew-tap` and pushes it to that repository's `main`. If this job fails, the release and the version commit stay: re-run the job, or edit the cask by hand. It needs the `HOMEBREW_TAP_TOKEN` secret: a fine-grained token limited to the tap, with `Contents: Read and write`.

### Signing certificate

Releases are signed with a self-signed certificate (`CN=IonizedBar Signing`). TCC then pins the grants to `identifier + certificate leaf` instead of each build's cdhash. Losing the certificate means every user grants the permissions once more, so keep the `.p12` and its password in a password manager. The Release workflow imports it from the `SIGNING_CERT_P12` (base64 of the `.p12`) and `SIGNING_CERT_PASSWORD` secrets, and refuses to release an ad-hoc build. To create one (valid 10 years), then use the same `.p12` on your Mac so local builds share the grant:

```sh
openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 3650 -subj "/CN=IonizedBar Signing" \
  -addext "keyUsage=critical,digitalSignature" -addext "extendedKeyUsage=critical,codeSigning" -addext "basicConstraints=critical,CA:false"
openssl pkcs12 -export -legacy -inkey key.pem -in cert.pem -name "IonizedBar Signing" -out IonizedBar-signing.p12
security import IonizedBar-signing.p12 -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign
base64 -i IonizedBar-signing.p12 | gh secret set SIGNING_CERT_P12
gh secret set SIGNING_CERT_PASSWORD
```

`security find-identity -p codesigning` lists it as `CSSMERR_TP_NOT_TRUSTED`; that is expected and does not prevent signing.
