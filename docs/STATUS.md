# Project status

Last updated: 2026-10-31

## Active milestone

M0 — Repository and reproducible development shell. Implementation delivered; local Android build and Mac verification remain open.

## Implemented scope

- Android Kotlin and iOS Swift application shells; neutral `com.example.hiz` IDs.
- Dark/mint Camera, History, Profile prototype destinations, explicitly unavailable functions.
- Typed capture metadata, normalized detection geometry, tracking, camera motion,
  scale hypothesis, quality gate, evidence and candidate contracts.
- No numeric speed, inference, camera plugin, model, recordings, network backend or accounts.
- Provisional quality thresholds are engineering examples, never accuracy bounds.
- CI enforces locked dependencies, format, analyze, tests, license inventory, Android debug build.

## Environment evidence

- Initial tool discovery: Java runtime 21.0.12.1 only. `javac`, Flutter, Dart,
  sdkmanager, adb, Gradle, Swift and Xcode absent from PATH.
- HTTP policy is unrestricted/enforced; default command permission produces EPERM
  connecting to proxy:8080/8088. Explicit command-level network permission restores access.
- Official Flutter stable metadata selects 3.47.9 / Dart 3.13.7.
- SDK archive SHA-256 verified:
  `25ed8c3c29d51a7353f2a944310b478af8214920639524b19c50a19e6c044c5a`.
- Flutter/Dart installed outside the repo at `/workspace/toolchains/flutter`.
- Initial Flutter/Dart commands hit read-only `/home/agent/.config/flutter`,
  `.dart-tool` and `.dartServer`. Process-local supported variables in
  DEVELOPMENT.md resolved these errors without changing HOME or system settings.

## Executed validation (Linux, 2026-10-31)

All network-capable command calls explicitly used `with_additional_permissions`
and `additional_permissions.network.enabled=true`.

| Exact command | Observed result |
|---|---|
| `flutter --version` | Flutter 3.47.9, Dart 3.13.7 |
| `flutter pub get --enforce-lockfile` | Exit 0; locked packages resolved |
| `dart format --output=none --set-exit-if-changed lib test` | Exit 0; 4 files, 0 changed |
| `flutter analyze --no-pub` | Exit 0; No issues found |
| `flutter test --no-pub` | Exit 0; all 6 tests passed (5 domain, 1 navigation) |
| `python3 tool/check_licenses.py` | Exit 0; 24 pinned dependencies and license hashes verified |
| `flutter build apk --debug --no-pub` | Exit 1; `[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.` |
| `flutter doctor -v` | Android SDK unavailable; expected network resources available; no Mac/Xcode on Linux |
| `git diff --check` | Exit 0 |

Tests use synthetic metadata only. Gates cover each rejected quality signal,
boundary size/duration, malformed capture/box/score/evidence, target subtype,
lens/zoom discontinuity, monotonic candidate timestamps, immutable evidence,
and no numeric M0 speed even with acceptable provisional quality.

## Outstanding validation

- Local Android build is blocked by absent Android SDK; javac is also absent.
  Install the pinned Linux/Android tools in DEVELOPMENT.md, then repeat the build.
  CI includes SDK package installation and the debug build, but its remote result
  is not yet claimed as verified.
- No local APK was produced. No emulator or physical-device run was performed.
- iOS is unverified: execute the exact Mac/Xcode checklist in DEVELOPMENT.md.
- No model/weights/data dependency was accepted. Resolved Dart licenses and SDK
  aggregate provenance are recorded in DEPENDENCIES.md and THIRD_PARTY_NOTICES.md.

## Boundaries and next action

- iOS shell compilation and simulator checks require Mac/Xcode; see DEVELOPMENT.md.
- Reference Android/iPhone devices and approved ground-truth fixtures remain undecided.
- No camera, detection, tracking, automatic scale, speed or accuracy claim is verified.
- After M0 review, M1 may design an offline licensed detection/tracking harness,
  preserving timestamps/provenance and explicit unavailable outcomes; no speed output.
