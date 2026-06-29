# macOS Build, Signing, and Notarization

## Local build

Install dependencies:

```bash
brew install cmake ninja pkg-config qt@5 openssl@3
```

Build an unsigned universal release bundle:

```bash
B_BUILD_TYPE=Release \
B_MACOS_ARCHS="arm64;x86_64" \
./clean_build.sh
```

The generated app bundle and DMG are expected under `build/bundle/`.

## Signing inputs

Set these only for signed release builds:

```bash
export BARRIER_DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)"
export BARRIER_DEVELOPER_ID_INSTALLER="Developer ID Installer: Your Name (TEAMID)"
export BARRIER_NOTARY_PROFILE="barrier-notary"
```

Store the notary profile once:

```bash
xcrun notarytool store-credentials "$BARRIER_NOTARY_PROFILE" \
  --apple-id "apple-id@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

## Validation

Validate a signed app:

```bash
dist/macos/signing/validate_artifact.sh build/bundle/Barrier.app
```

Validate a signed and stapled DMG:

```bash
dist/macos/signing/validate_artifact.sh build/bundle/Barrier-*.dmg
```
