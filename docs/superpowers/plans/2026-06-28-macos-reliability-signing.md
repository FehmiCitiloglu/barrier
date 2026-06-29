# macOS Reliability and Signing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Barrier produce a reliable, native Apple Silicon capable macOS app bundle that can be Developer ID signed, notarized, and validated before deeper runtime refactors begin.

**Architecture:** Treat macOS modernization as separate, testable tracks: build/distribution first, runtime permissions second, and input/clipboard/file-transfer reliability third. The first track keeps the existing Qt GUI and CMake project, adds explicit macOS build options, introduces signing/notarization scripts, and documents validation commands so every release artifact is reproducible.

**Tech Stack:** CMake, C++14/Objective-C++, Qt 5 initially with a Qt 6 compatibility branch after the signed universal build is reproducible, macdeployqt, codesign, notarytool, stapler, hdiutil, GitHub Actions or local shell scripts.

---

## Scope Split

Barrier currently mixes old macOS runtime APIs, legacy Qt5 packaging, Azure CI, and unsigned release artifacts. This plan is the first implementation slice only: build, bundle, sign, notarize, and validate macOS artifacts. Follow-up plans should separately cover:

- Runtime permission UX: Accessibility, Input Monitoring, Screen Recording if needed, local network, and startup items.
- Native input reliability: Quartz event taps, synthetic events, secure input detection, display reconfiguration, sleep/wake, multi-display coordinates, and fast user switching.
- Clipboard and file transfer reliability: pasteboard format coverage, large payloads, history policy, drag/drop, folder transfer constraints, and cross-version compatibility.
- GUI modernization: Qt 6 or native Swift/AppKit wrapper decision after the runtime surface is stable.

## Current Findings

- Fork is `https://github.com/FehmiCitiloglu/barrier`.
- Local remotes are `origin=https://github.com/FehmiCitiloglu/barrier.git` and `upstream=https://github.com/debauchee/barrier.git`.
- Default branch is `master`, whose latest local commit is `653e4bad` from 2022.
- Upstream repository metadata reports later repository activity, but not on `master`; there are abandoned branches named `enhancement/builds/macos-universal` and `enhancement/builds/macos-universal-qt6-test`.
- `azure-pipelines.yml` still builds macOS on old hosted images and installs `qt5`.
- `clean_build.sh` hardcodes `-DCMAKE_OSX_DEPLOYMENT_TARGET=10.9`.
- `src/gui/res/mac/Info.plist` has stale identifiers and versions: `CFBundleIdentifier=barrier`, `CFBundleShortVersionString=1.8.8`.
- `cmake/Package.cmake` only configures `TBZ2` for Unix packaging.
- `dist/macos/bundle/build_dist.sh.in` calls `macdeployqt` and produces a DMG, but does not sign, notarize, staple, or validate.
- `src/lib/platform/OSXScreen.mm` still uses Carbon event handlers and Accessibility trust checks; that work is intentionally deferred to the runtime reliability plan.

## Files

- Modify: `CMakeLists.txt`
- Modify: `clean_build.sh`
- Modify: `src/gui/res/mac/Info.plist`
- Modify: `dist/macos/bundle/build_dist.sh.in`
- Create: `dist/macos/signing/Barrier.entitlements`
- Create: `dist/macos/signing/sign_bundle.sh`
- Create: `dist/macos/signing/notarize_dmg.sh`
- Create: `dist/macos/signing/validate_artifact.sh`
- Create: `.github/workflows/macos-build.yml`
- Create: `docs/macos/build-sign-notarize.md`

## Task 1: Capture macOS Build Baseline

**Files:**
- Create: `docs/macos/build-sign-notarize.md`

- [x] **Step 1: Add the initial build documentation**

Create `docs/macos/build-sign-notarize.md`:

````markdown
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
````

- [x] **Step 2: Commit the baseline documentation**

Run:

```bash
git add docs/macos/build-sign-notarize.md
git commit -m "docs: add macos signing build notes"
```

Expected: one documentation-only commit.

## Task 2: Add Explicit Universal macOS Build Flags

**Files:**
- Modify: `clean_build.sh`
- Modify: `CMakeLists.txt`

- [ ] **Step 1: Update `clean_build.sh` to accept configurable macOS arch and deployment target**

Replace the Darwin block in `clean_build.sh` with:

```sh
if [ "$(uname)" = "Darwin" ]; then
    . ./osx_environment.sh
    B_MACOS_DEPLOYMENT_TARGET=${B_MACOS_DEPLOYMENT_TARGET:-11.0}
    B_MACOS_ARCHS=${B_MACOS_ARCHS:-arm64}
    B_CMAKE_FLAGS="-DCMAKE_OSX_SYSROOT=$(xcode-select --print-path)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk -DCMAKE_OSX_DEPLOYMENT_TARGET=$B_MACOS_DEPLOYMENT_TARGET -DCMAKE_OSX_ARCHITECTURES=$B_MACOS_ARCHS $B_CMAKE_FLAGS"
fi
```

- [ ] **Step 2: Raise CMake version only enough for modern macOS behavior**

Change the first CMake line in `CMakeLists.txt`:

```cmake
cmake_minimum_required (VERSION 3.20)
```

- [ ] **Step 3: Configure a universal build**

Run:

```bash
B_BUILD_TYPE=Release B_MACOS_ARCHS="arm64;x86_64" ./clean_build.sh
```

Expected: CMake configure output includes `CMAKE_OSX_ARCHITECTURES=arm64;x86_64`; if it fails, record the dependency or compiler error in the next commit message body.

- [ ] **Step 4: Commit the build flag changes**

Run:

```bash
git add CMakeLists.txt clean_build.sh
git commit -m "build: make macos architectures configurable"
```

## Task 3: Correct Bundle Metadata

**Files:**
- Modify: `src/gui/res/mac/Info.plist`

- [ ] **Step 1: Replace stale bundle identifiers and version placeholders**

Change the bundle identifier and version fields:

```xml
<key>CFBundleIdentifier</key>
<string>org.barrier-foss.Barrier</string>
<key>CFBundleShortVersionString</key>
<string>${BARRIER_VERSION}</string>
<key>CFBundleVersion</key>
<string>${BARRIER_VERSION}</string>
<key>NSHumanReadableCopyright</key>
<string>Copyright (c) Barrier contributors</string>
```

- [ ] **Step 2: Verify the generated bundle plist**

Run:

```bash
plutil -p build/bundle/Barrier.app/Contents/Info.plist
```

Expected: `CFBundleIdentifier` is `org.barrier-foss.Barrier` and both version keys match the project version.

- [ ] **Step 3: Commit the bundle metadata change**

Run:

```bash
git add src/gui/res/mac/Info.plist
git commit -m "build: update macos bundle metadata"
```

## Task 4: Add Signing Entitlements and Bundle Signing Script

**Files:**
- Create: `dist/macos/signing/Barrier.entitlements`
- Create: `dist/macos/signing/sign_bundle.sh`

- [ ] **Step 1: Add minimal hardened runtime entitlements**

Create `dist/macos/signing/Barrier.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
```

- [ ] **Step 2: Add recursive bundle signing script**

Create `dist/macos/signing/sign_bundle.sh`:

```sh
#!/bin/sh
set -eu

APP_PATH=${1:?Usage: sign_bundle.sh /path/to/Barrier.app}
IDENTITY=${BARRIER_DEVELOPER_ID_APP:?Set BARRIER_DEVELOPER_ID_APP to a Developer ID Application identity}
ENTITLEMENTS=${BARRIER_ENTITLEMENTS:-dist/macos/signing/Barrier.entitlements}

if [ ! -d "$APP_PATH/Contents" ]; then
    echo "Not an app bundle: $APP_PATH" >&2
    exit 1
fi

find "$APP_PATH/Contents/Frameworks" -type f \( -name "*.dylib" -o -perm -111 \) -print 2>/dev/null | while IFS= read -r item; do
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$item"
done

find "$APP_PATH/Contents/PlugIns" -type f -print 2>/dev/null | while IFS= read -r item; do
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$item"
done

codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl -a -vv "$APP_PATH"
```

- [ ] **Step 3: Make the script executable**

Run:

```bash
chmod +x dist/macos/signing/sign_bundle.sh
```

- [ ] **Step 4: Test unsigned failure path**

Run:

```bash
dist/macos/signing/sign_bundle.sh build/bundle/Barrier.app
```

Expected: FAIL with `Set BARRIER_DEVELOPER_ID_APP`.

- [ ] **Step 5: Commit signing script and entitlements**

Run:

```bash
git add dist/macos/signing/Barrier.entitlements dist/macos/signing/sign_bundle.sh
git commit -m "build: add macos bundle signing script"
```

## Task 5: Add Notarization and Validation Scripts

**Files:**
- Create: `dist/macos/signing/notarize_dmg.sh`
- Create: `dist/macos/signing/validate_artifact.sh`

- [ ] **Step 1: Add notarization script**

Create `dist/macos/signing/notarize_dmg.sh`:

```sh
#!/bin/sh
set -eu

DMG_PATH=${1:?Usage: notarize_dmg.sh /path/to/Barrier.dmg}
PROFILE=${BARRIER_NOTARY_PROFILE:?Set BARRIER_NOTARY_PROFILE to a notarytool keychain profile}

xcrun notarytool submit "$DMG_PATH" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
```

- [ ] **Step 2: Add validation script**

Create `dist/macos/signing/validate_artifact.sh`:

```sh
#!/bin/sh
set -eu

ARTIFACT=${1:?Usage: validate_artifact.sh /path/to/Barrier.app-or-dmg}

case "$ARTIFACT" in
    *.app)
        codesign -dvvv --entitlements :- "$ARTIFACT"
        codesign --verify --deep --strict --verbose=2 "$ARTIFACT"
        spctl -a -vv "$ARTIFACT"
        ;;
    *.dmg)
        xcrun stapler validate "$ARTIFACT"
        spctl -a -vv -t open "$ARTIFACT"
        ;;
    *)
        echo "Unsupported artifact type: $ARTIFACT" >&2
        exit 1
        ;;
esac
```

- [ ] **Step 3: Make scripts executable**

Run:

```bash
chmod +x dist/macos/signing/notarize_dmg.sh dist/macos/signing/validate_artifact.sh
```

- [ ] **Step 4: Test argument validation**

Run:

```bash
dist/macos/signing/notarize_dmg.sh
dist/macos/signing/validate_artifact.sh
```

Expected: both commands fail with their usage messages.

- [ ] **Step 5: Commit notarization scripts**

Run:

```bash
git add dist/macos/signing/notarize_dmg.sh dist/macos/signing/validate_artifact.sh
git commit -m "build: add macos notarization validation scripts"
```

## Task 6: Wire Signing into DMG Build Without Requiring Secrets

**Files:**
- Modify: `dist/macos/bundle/build_dist.sh.in`

- [ ] **Step 1: Add optional signing after `macdeployqt`**

After the release `macdeployqt` command and before moving the DMG, add:

```sh
if [ -n "${BARRIER_DEVELOPER_ID_APP:-}" ]; then
    info "Signing Barrier.app"
    "@CMAKE_SOURCE_DIR@/dist/macos/signing/sign_bundle.sh" Barrier.app || exit 1
else
    warn "BARRIER_DEVELOPER_ID_APP is not set; Barrier.app will remain unsigned"
fi
```

- [ ] **Step 2: Add optional notarization after DMG creation**

After `mv "Barrier.dmg" "Barrier-$B_VERSION.dmg" || exit 1`, add:

```sh
if [ -n "${BARRIER_NOTARY_PROFILE:-}" ]; then
    info "Notarizing Barrier-$B_VERSION.dmg"
    "@CMAKE_SOURCE_DIR@/dist/macos/signing/notarize_dmg.sh" "Barrier-$B_VERSION.dmg" || exit 1
else
    warn "BARRIER_NOTARY_PROFILE is not set; Barrier-$B_VERSION.dmg will not be notarized"
fi
```

- [ ] **Step 3: Build unsigned release DMG**

Run:

```bash
B_BUILD_TYPE=Release ./clean_build.sh
```

Expected: build succeeds or reaches existing dependency failures; if it succeeds, output warns that signing and notarization were skipped.

- [ ] **Step 4: Commit optional signing integration**

Run:

```bash
git add dist/macos/bundle/build_dist.sh.in
git commit -m "build: wire optional macos signing into distribution"
```

## Task 7: Add GitHub Actions macOS Build Matrix

**Files:**
- Create: `.github/workflows/macos-build.yml`

- [ ] **Step 1: Add unsigned CI build for arm64 and universal configuration**

Create `.github/workflows/macos-build.yml`:

```yaml
name: macOS Build

on:
  push:
    branches: [master, "codex/**"]
  pull_request:

jobs:
  macos:
    runs-on: macos-14
    strategy:
      fail-fast: false
      matrix:
        archs:
          - arm64
          - "arm64;x86_64"
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - name: Install dependencies
        run: brew install cmake ninja pkg-config qt@5 openssl@3
      - name: Build
        env:
          B_BUILD_TYPE: Release
          B_MACOS_ARCHS: ${{ matrix.archs }}
        run: ./clean_build.sh
      - name: Upload bundle
        uses: actions/upload-artifact@v4
        with:
          name: barrier-macos-${{ matrix.archs }}
          path: build/bundle
```

- [ ] **Step 2: Validate workflow syntax locally if `actionlint` is installed**

Run:

```bash
command -v actionlint >/dev/null && actionlint .github/workflows/macos-build.yml || true
```

Expected: no output when `actionlint` is installed; otherwise the command exits successfully without validation.

- [ ] **Step 3: Commit the GitHub Actions workflow**

Run:

```bash
git add .github/workflows/macos-build.yml
git commit -m "ci: add macos release build workflow"
```

## Task 8: Release Gate Checklist

**Files:**
- Modify: `docs/macos/build-sign-notarize.md`

- [ ] **Step 1: Add release gate checklist**

Append to `docs/macos/build-sign-notarize.md`:

````markdown
## Release gate

A macOS release is not ready unless all commands pass:

```bash
lipo -archs build/bundle/Barrier.app/Contents/MacOS/barrier
lipo -archs build/bundle/Barrier.app/Contents/MacOS/barrierc
lipo -archs build/bundle/Barrier.app/Contents/MacOS/barriers
codesign --verify --deep --strict --verbose=2 build/bundle/Barrier.app
spctl -a -vv build/bundle/Barrier.app
xcrun stapler validate build/bundle/Barrier-*.dmg
spctl -a -vv -t open build/bundle/Barrier-*.dmg
```

Expected architecture output for the universal release:

```text
x86_64 arm64
```
````

- [ ] **Step 2: Commit release gate documentation**

Run:

```bash
git add docs/macos/build-sign-notarize.md
git commit -m "docs: document macos release validation gate"
```

## Follow-Up Plan Seeds

Create separate plans after this slice lands:

- `macos-runtime-permissions`: add permission preflight helpers around Accessibility trust and modern System Settings deep links, then expose status in GUI before server startup.
- `macos-input-eventtap-reliability`: replace Carbon event queue usage where possible, audit secure input and event tap failure recovery, and add manual QA scripts for keyboard/mouse transitions.
- `macos-clipboard-file-transfer`: make pasteboard sync observable, add size limits and error reporting, and decide whether folder sharing belongs in Barrier core or a separate secure transfer channel.
- `qt6-apple-silicon`: port CMake discovery from Qt5 to Qt5/Qt6 dual mode only after signed Qt5 universal artifacts are reproducible.

## Self-Review

- Spec coverage: this plan covers fork orientation, Apple Silicon/universal build readiness, Developer ID signing, notarization, and release validation. Runtime refactor work is intentionally split into follow-up plans because it crosses independent subsystems.
- Placeholder scan: no task uses `TBD`, `TODO`, or unbounded "handle edge cases" instructions.
- Type consistency: shell variable names are consistent across scripts and documentation: `BARRIER_DEVELOPER_ID_APP`, `BARRIER_NOTARY_PROFILE`, `BARRIER_ENTITLEMENTS`, `B_MACOS_ARCHS`, and `B_MACOS_DEPLOYMENT_TARGET`.
