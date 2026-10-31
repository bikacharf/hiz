# Project status

Last updated: 2026-10-31

## Current phase

M0 — development shell implemented and Linux/Android gates passed.
iOS explicitly requires Mac/Xcode verification.

## Confirmed product decisions

- Android and iOS; dark UI and mint accent.
- Person, bicycle, vehicle and football/basketball/tennis are target classes.
- No user-entered distance or manual calibration.
- Observable measurement quality gates are independent of accuracy claims.
- Free/Pro direction remains unchanged; no payments implemented.

## Delivered in M0

- Flutter 3.47.9 / Dart 3.13.7 Android+iOS generated hosts with documented
  placeholder identifiers; Temurin JDK 21.0.13+9 and generated Gradle/AGP/Kotlin pins.
- Typed capture, detection, tracking, camera motion, scale, speed, quality and
  evidence contracts, validation and immutable evidence containers.
- Unknown/failed quality gates block numeric candidates; optics changes and
  non-monotonic capture timestamps reject a track.
- Dark/mint Home, Camera, History and Profile route shell. Every page discloses
  nonfunctional prototype status. No camera, detection, tracking, scale or speed
  implementation; no numeric speed or simulated production data.
- Eight tests, CI gate sequence, Linux setup and verification helpers, complete
  locked Dart dependency inventory and copied original license notices.
- Existing secret/private media ignore rules retained. No models, datasets,
  backend, analytics, billing, upload, or new restrictive application dependency.

## Validation evidence

See `docs/validation/toolchain-before.txt`, `shared-checks.txt`,
`flutter-doctor.txt` and `docs/DEVELOPMENT.md` for commands and setup.

| Command | Result |
|---|---|
| Flutter SDK SHA-256 verification | PASS, official stable archive |
| flutter pub get --enforce-lockfile | PASS, 26 locked Dart packages |
| dart format --output=none --set-exit-if-changed lib test | PASS, 4 files unchanged |
| flutter analyze --no-pub | PASS, no issues |
| flutter test --no-pub | PASS, 8 tests |
| python3 tool/check_licenses.py | PASS, all 26 packages inventoried |
| flutter build apk --debug --no-pub | PASS, app-debug.apk produced in 46.4 seconds |
| bash -n tool/setup_linux.sh tool/verify.sh | PASS (syntax only) |
| git diff --cached --check | PASS, upstream license whitespace preserved |

CI is configured but its remote run is not claimed as verified. The setup helper
was syntax-checked; its component commands were exercised during setup, not a
second complete clean-machine installation. License automation covers locked
Dart packages; platform SDK/build-tool distributions retain their upstream terms
and transitive notices. It is not a legal certification or exhaustive Maven audit.

## Platform and feasibility limits

- Linux provides no iOS compile/runtime validation. Follow the exact simulator
  and unsigned-device build checklist in DEVELOPMENT.md on a Mac with Xcode.
- Doctor reports missing web/Linux desktop tools, outside Android+iOS scope.
  Its device probe cannot create ~/.android on this read-only user home; no
  device availability is asserted. Use writable tool state and a reference phone
  during the appropriate milestone.
- Android and iPhone reference models remain unspecified. No physical-device
  performance, thermal, alignment, capture or measurement behavior is validated.
- No approved validation recordings or independent ground truth exist.
- Quality gates and schemas are architecture scaffolding; no threshold or scale
  method has been empirically accepted, and no accuracy claim is made.

## Next action

Review M0 evidence and complete the Mac/Xcode checks. Then plan M1: licensed offline detection/tracking harness with approved fixtures,
repeatable evidence, explicit unsupported cases, and no numeric speed output.

## Android build evidence and resolved environment blockers

Final command: `flutter build apk --debug --no-pub`, exit 0, 46.4 seconds.
Output: `build/app/outputs/flutter-apk/app-debug.apk` (generated/ignored).
Full successful output: `docs/validation/android-build-final.txt`.
The app has not been launched on a physical phone.

- NDK extraction first exhausted workspace storage; log:
  `docs/validation/android-build-first.txt`.
- The preinstalled Java 21 was a JRE without javac; log:
  `docs/validation/android-build-jre-only.txt`. Installed session-only Temurin
  JDK 21.0.13+9; exact final versions: `toolchain-final.txt` in validation.
- The downloaded JDK required the configured system proxy CA trust store;
  TLS validation remained enabled. Session Gradle properties are documented in
  DEVELOPMENT.md, with a 2 GiB heap and two workers.
- Native library merging then exhausted workspace storage; log:
  `docs/validation/android-build-disk.txt`. Moved Flutter and NDK to the separate
  temporary volume with stable SDK-path symlinks, leaving build/Gradle caches
  on workspace and setting TMPDIR to writable workspace tool storage.
- The final successful build used JAVA_HOME, PUB_CACHE, XDG_CONFIG_HOME,
  ANDROID_HOME, ANDROID_USER_HOME and GRADLE_USER_HOME outside the repository.
  All remote network command invocations requested the explicit additional
  network permission. No environment workaround is a portable app dependency.
