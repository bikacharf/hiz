# Project status

Last updated: 2026-11-01

## Current phase

M1 — local-video picker/decoder and detector integration is validated on
`codex/m1-local-video-decoder`; **M1 is not complete**. Physical Android/iPhone
runtime verification and real-video tracking evidence remain pending.

## M1 local-video slice

- Added a dependency-free platform channel for local video selection and
  session-scoped decoding. Video remains on device.
- Android uses the system document picker plus MediaExtractor/MediaCodec flexible
  YUV output. iOS uses a copied document-picker URL plus AVAssetReader BGRA output.
- Both native paths downsample to a maximum 640-pixel side, rotate to upright
  RGB888, and return source presentation timestamps rather than UI/FPS timing.
- Dart validates metadata, byte counts, strictly increasing PTS and closed-session
  behavior. Failures never substitute a synthetic frame.
- Added a visible `Yerel video analizi` screen that analyzes at most 120 frames
  and reports coarse detection counts only. Tracking and speed remain unavailable.
- No dependency, model, dataset or network service was added.
- GitHub Actions run 41252643668 on commit `a5c5c8a` passed 40 Flutter tests,
  static analysis, the 30-package plus one-model license gate, and Android APK
  creation. Its macOS job used Xcode 16.4 and produced an iOS simulator
  `Runner.app`; this proves Swift compilation, not physical-device behavior.
- Picker interaction, codec output correctness across device vendors, portrait/
  landscape orientation, inference latency, memory and thermal behavior still
  require approved videos on named physical Android and iPhone devices.

## M1 licensed detector slice

- Bundled TensorFlow EfficientDet-Lite0 metadata variation 1 from the canonical
  Kaggle TensorFlow download: 4,563,519 bytes, SHA-256
  `2e04c53bfeac0ac2a30c057c7e2a777594ce39baaac35a92f74fb1e8c4fc4e0b`.
- Added tflite_flutter 0.12.1 and its exact locked permissive dependencies.
  The offline license gate now checks 30 packages plus the model binary, size,
  hash and license notice.
- Added a strict RGB888/source-PTS adapter, deterministic aspect-preserving
  letterbox transform, source-coordinate box conversion, tensor-contract checks,
  score filtering and coarse COCO mapping for person/bicycle/vehicle/sports ball.
- Coarse sports-ball output never invents football/basketball/tennis subtype.
  The domain allows an untyped coarse ball detection but blocks numeric ball
  speed until a subtype exists.
- The real LiteRT wrapper remains isolated from pure unit tests and is now loaded
  by the local-video prototype only after explicit file selection. No failed
  inference produces mock detections.
- GitHub Actions run 41249022684 on commit `574488d` passed the locked package
  restore, format, analysis, all 36 tests, the 30-package plus one-model license
  gate, and a real Android debug APK build with Flutter 3.47.9.
- CI was repaired for the removed Android SDK `tools` package, current Java 21
  patch resolution, and Java/Kotlin bytecode target alignment across Flutter
  plugin modules. The detector now validates active boxes before score/class
  filtering so malformed model output fails closed.
- Local `python tool/check_licenses.py` also passes. This Windows machine still
  has no installed Flutter SDK; the full Flutter gates above were run remotely.
  Physical-device and iOS checks remain pending, so do not infer runtime speed,
  thermal, camera, or measurement accuracy from the successful APK build.

## M1 first slice and evidence

- Deterministic synthetic detection-fixture input with explicit person/bicycle/
  vehicle/car/ball annotation mapping and unsupported labels.
- Single-target geometry association preserves identity for up to two supplied
  missed frames; the third miss ends the identity. This is not
  an elapsed-time loss policy; arbitrarily long PTS gaps alone do not expire it.
  Subsequent acquisition creates a new ID. Ambiguity never picks a candidate based on order or score.
- Mandatory schema-2 source manifest: sourcePtsUs only, normalizedTopLeft,
  integer rotation 0, declared frame count, syntheticAnnotations adapter version 1.
  All fields are validated and included in every per-frame evidence record.
- Explicit selection, class changes, lens/zoom/image-geometry discontinuities,
  monotonic capture timestamps, source provenance and per-frame JSONL evidence.
- Review tests cover all-empty detection sequences without omitted records,
  irregular source PTS (including long gaps) without invented FPS/time expiry,
  complete metadata in every record and canonical JSONL semantic round-trips.
- Bundled repository-authored synthetic fixture plus expected evidence and tests.
  No camera frames, personal media, model weights or inference are involved.
- Labeled app screen runs the same synthetic fixture; it is not video detection.
  Every evidence record marks measurementAvailable=false and has no speed field.
- No new dependency. Existing 26-package version/license/notice-hash gate passes.

| M1 validation command | Observed result |
|---|---|
| flutter pub get --enforce-lockfile | PASS; lockfile unchanged |
| dart format --output=none --set-exit-if-changed lib test tool | PASS; 10 files unchanged |
| flutter analyze --no-pub | PASS; no issues, 6.4 seconds |
| flutter test --no-pub | PASS; 26 tests (14 harness, 2 widget, 10 existing domain) |
| python3 tool/check_licenses.py | PASS; 26 unchanged dependency records |
| flutter build apk --debug --no-pub | PASS; APK produced in 6.2 seconds |
| CLI export twice + cmp against expected evidence | PASS; byte-identical JSONL |
| CLI input/output alias and malformed input checks | PASS; nonzero exit, no invalid output |

Exact evidence and fixture hashes: docs/validation/m1-checks.txt.
Android build was not a device run. Remote CI and iOS compilation were not
verified here. All network-capable validation commands carried explicit additional
network permission; session-only tool/cache/CA settings follow DEVELOPMENT.md.

## Remaining M1 blockers and next action

1. Run the bundled model/runtime on physical Android and iOS devices and audit
   the notices inside generated release binaries before distribution.
2. Validate the new local-video decoder with approved portrait/landscape videos
   on a named Android reference device and run the documented Mac/Xcode check.
   Then connect decoded detections to target selection/tracking evidence before
   claiming real tracking behavior.
3. Source-content hashing and evidence-to-source cryptographic binding are
   deferred. No crypto dependency was added. Declared fixture IDs/metadata and
   repository validation SHA values do not replace per-artifact content identity.
4. Mac/Xcode and reference-device validation remain open. Follow DEVELOPMENT.md
   and additionally exercise the labeled offline screen on the simulator.

See M1_OFFLINE_HARNESS.md for policies, schemas, association limitations and
reproduction. M1 remains partial; no scale, speed or accuracy claim is made.

## Historical M0 evidence (retained below)

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
- Eleven tests, CI gate sequence, Linux setup and verification helpers, complete
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
| dart format --output=none --set-exit-if-changed lib test | PASS, 6 files unchanged |
| flutter analyze --no-pub | PASS, no issues |
| flutter test --no-pub | PASS, 11 tests |
| python3 tool/check_licenses.py | PASS, all 26 packages inventoried |
| flutter build apk --debug --no-pub | PASS, app-debug.apk produced in 4.1 seconds |
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

## M0 handoff (historical)

Review M0 evidence and complete the Mac/Xcode checks. Then plan M1: licensed offline detection/tracking harness with approved fixtures,
repeatable evidence, explicit unsupported cases, and no numeric speed output.

## Android build evidence and resolved environment blockers

Final command: `flutter build apk --debug --no-pub`, exit 0, 4.1 seconds.
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

The final merged branch was revalidated: format (6 files), analysis (no issues,
6.6 seconds), 11 tests, 26 package license/version/notice-hash checks, and Android
debug build (4.1 seconds, cached toolchain). The existing remote M0 commit remains
in history. contracts.dart exports the single canonical measurement model; no
duplicate provisional quality-threshold implementation remains.
