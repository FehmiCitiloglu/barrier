# Native macOS test builds

The new test packages target macOS 15 or later:

- `Barrier-<version>-macos-arm64.dmg`: Apple Silicon, native execution.
- `Barrier-<version>-macos-x86_64.dmg`: Intel Macs.

These are ad-hoc-signed test downloads, not notarized public releases. Native
support is pending the automated and manual acceptance checks below. The network
protocol, configuration format and command-line interface are unchanged.

## Build

Install Xcode or its command-line tools, Python 3.9+, CMake 3.31.x, Qt 5 and
OpenSSL. Homebrew users can install `qt@5 openssl@3 pkgconf`.
[Qt 5 is deprecated in Homebrew](https://formulae.brew.sh/formula/qt@5);
this milestone retains Qt 5 and defers migration to Qt 6.

Build on a machine with dependencies matching the chosen architecture:

```sh
git submodule update --init --recursive
cmake -S . -B build/arm64-release \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_PREFIX_PATH="$(brew --prefix qt@5)" \
  -DOPENSSL_ROOT_DIR="$(brew --prefix openssl@3)"
cmake --build build/arm64-release --parallel 3
ctest --test-dir build/arm64-release --output-on-failure
```

Use `x86_64` and an Intel dependency installation for the Intel package. Repeat
with `Debug` in a separate build directory. SDK discovery uses `xcrun`; explicit
`CMAKE_OSX_SYSROOT`, `CMAKE_OSX_DEPLOYMENT_TARGET`, architecture and dependency
selections are honored. Custom deployment targets produce custom test packages;
release acceptance requires 15.0. Universal DMGs are outside this milestone.

The packaging target copies only `barrier`, `barrierc`, and `barriers`, deploys
with the selected Qt's `macdeployqt`, signs after relocation, and validates every
Mach-O file before creating a Release DMG under the build's `bundle` directory.
Validation checks architecture, minimum OS, signatures, dependency resolution,
and external library/rpath leakage. A dependency built for a newer OS must be
replaced by a compatible build; lowering the application's target cannot fix it.

## Automated regression evidence

`.github/workflows/cross-platform.yml` builds Debug and Release for native
[macos-15 and macos-15-intel runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners),
Windows 2022 x64 and Ubuntu 22.04 x64, alongside the existing Azure configuration.
Windows retains Qt 5.13.0, bundled OpenSSL and the existing Bonjour package;
Linux uses Ubuntu's Qt 5 and system libraries. CMake is pinned to 3.31.6.
Windows and Linux run the same commands against immutable baseline
`653e4badeb88f61de901581667d4465d7b1e2d52` and the candidate. Compare both job
logs and uploaded XML results; a failure in both is pre-existing, not a pass.
All required candidate checks must pass before acceptance. Do not infer results
from workflow presence alone.

Core `unittests`, GUI `guiunittests`, and `integtests` are explicitly exercised.
Linux GUI/integration runs use Xvfb. macOS excludes `OSXKeyStateTests` input
injection and the currently commented-out `OSXScreenTests` from unattended
CTest; execute the key-state suite interactively after granting permissions.
Existing disabled tests remain disabled. The legacy qmake `guitests` directory
is not the maintained CMake GUI suite.

## Manual acceptance record (required before support is declared)

Record candidate commit, DMG SHA-256, Mac model/OS, peer OS/version, date,
tester, result and observed failures for each row. All rows are **pending**.
Use a clean Apple Silicon Mac without Rosetta or development dependencies and
also test the Intel package on macOS 15. Test with both Windows and Linux peers,
with the Mac taking each role (server and client).

| Check | Apple Silicon / Windows | Apple Silicon / Linux | Intel / Windows | Intel / Linux |
| --- | --- | --- | --- | --- |
| Packaged GUI and both backend executables launch | Pending | Pending | Pending | Pending |
| Keyboard, modifiers, layouts | Pending | Pending | Pending | Pending |
| Mouse movement, buttons, scrolling | Pending | Pending | Pending | Pending |
| Clipboard in both directions | Pending | Pending | Pending | Pending |
| TLS certificate pairing and rejection | Pending | Pending | Pending | Pending |
| Disconnect and reconnect | Pending | Pending | Pending | Pending |
| Accessibility/Input Monitoring denied: clean error, no crash | Pending | Pending | Pending | Pending |
| Permissions granted: restart and input works | Pending | Pending | Pending | Pending |
| Sleep/wake and reconnect | Pending | Pending | Pending | Pending |

Run `integtests --gtest_filter=OSXKeyStateTests.*` only in an interactive test
session with permission to inject input. CI cannot establish permission behavior,
clean-machine deployment, or physical cross-platform input compatibility.
Developer ID signing, notarization and public release publication are deferred.

## Local implementation verification — 2026-09-05

Host: arm64 macOS 26.6.2, AppleClang 21, CMake 3.31.6, Homebrew Qt
5.15.19 and OpenSSL 3.6.3. Both Debug and Release compiled all six executables
(`barrier`, `barrierc`, `barriers`, `unittests`, `guiunittests`, `integtests`).

- Core: 133/135 passed in both configurations.
- GUI: 58/58 passed in both configurations.
- Unattended integration: 12/14 passed with pasteboard access in both configurations.
- The unchanged baseline was built separately on this host: the same two core
  failures (`SecureUtilsTest.FormatSslFingerprintHexWithSeparators`,
  `SecureUtilsTest.CreateFingerprintRandomArt`) and two clipboard failures
  (`OSXClipboardTests.add_newValue_valueWasStored`,
  `OSXClipboardTests.add_replaceValue_valueWasReplaced`) reproduced. These
  pre-existing failures are recorded, not suppressed. The random fixture uses
  `uniform_int_distribution`, whose output differs between standard libraries.
- Five real Mach-O validator tests passed: valid package, wrong architecture,
  newer minimum OS, external rpath and modified signature.
- Configuring x86_64 with arm64 OpenSSL correctly failed early.
- The real arm64 bundle was relocated and ad-hoc signed; package validation
  correctly rejected Homebrew dependencies requiring macOS 26 (first failure:
  `libpcre2-16.0.dylib`). No macOS 15-compatible DMG was produced locally.

Windows/Linux baseline and candidate CI, native Intel builds, compatible DMGs,
and all physical smoke tests remain unverified. Build the DMGs on the macOS 15
runners with compatible dependencies before acceptance. No public release or
remote CI run was initiated during local verification.
