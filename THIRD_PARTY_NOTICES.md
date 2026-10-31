# Third-party notices — M0

Commercial compatibility review: only permissive Flutter/Dart ecosystem components
and platform build tools are admitted. No detector, model, weights or dataset is
included. The application remains proprietary; third-party terms still apply.

## Toolchain and platform code

| Component | Version | Source | License | Purpose/review |
|---|---|---|---|---|
| Flutter SDK/framework and generated embedding | 3.47.9 / c197ca5199e9ee5661e865596c9c07294dfab51c | https://github.com/flutter/flutter | BSD-3-Clause | Shared UI and generated hosts; attribution retained |
| Dart SDK | 3.13.7 | https://github.com/dart-lang/sdk | BSD-3-Clause | Compiler/runtime; toolchain notices retained in SDK |
| Flutter engine / Skia | bundled with Flutter 3.47.9 | https://github.com/flutter/engine | BSD-3-Clause and bundled third-party notices | Engine binary distribution notices must accompany release; SDK NOTICES retained |
| OpenJDK | 21.0.12.1 | https://openjdk.org/ | GPL-2.0-only WITH Classpath-exception-2.0 | Build tool only, not app-bundled; no GPL application dependency added |
| Android SDK | command-line tools 19.0; platform 36; build-tools 36.0.0 | https://developer.android.com/studio | Android SDK License Agreement | Platform tooling only; user/CI must review terms |
| Android NDK | 28.2.13676358 (Flutter pin) | https://developer.android.com/ndk | Android SDK agreement; bundled LLVM Apache-2.0 WITH LLVM-exception and component notices | Build only, upstream notices retained in toolchain |
| Apple iOS SDK / Xcode | not installed locally | https://developer.apple.com/xcode/ | Apple SDK agreement | Mac validation only; proprietary platform terms |
| Gradle | generated wrapper pin recorded below | https://github.com/gradle/gradle | Apache-2.0 | Build only; wrapper attribution retained |
| Android Gradle plugin | generated pin recorded below | https://android.googlesource.com/platform/tools/base | Apache-2.0 | Build only |
| Kotlin Gradle plugin / stdlib | generated pin recorded below | https://github.com/JetBrains/kotlin | Apache-2.0 | Android host/build |

The OpenJDK license is a pre-existing environment tool, not newly bundled GPL code.
Android/iOS platform and Flutter engine transitive system components are not newly
selected packages. Before distributing a release, collect complete engine/platform
notices from the built release; M0 does not distribute a product binary.

## CI tooling (not bundled)

- actions/checkout v4: MIT, https://github.com/actions/checkout
- actions/setup-java v4: MIT, https://github.com/actions/setup-java
- android-actions/setup-android v3: MIT, https://github.com/android-actions/setup-android
- subosito/flutter-action v2: MIT, https://github.com/subosito/flutter-action

## Dart package inventory

Exact direct, development, and transitive versions are locked in pubspec.lock.
The complete resolved package table below and license copies in docs/licenses
are checked by tool/check_licenses.py. Any new package or changed version requires
renewed source/license review before updating that inventory.

Pre-resolution review: flutter_test (SDK-pinned) and flutter_lints 6.0.0
(https://github.com/flutter/packages/tree/main/packages/flutter_lints,
BSD-3-Clause) are development-only. Their resolved permissive dependencies are
listed below with original license text. No third-party runtime plugin is selected.
Material Icons font is generated through Flutter's uses-material-design option;
source https://github.com/google/material-design-icons, Apache-2.0.
Build pins: Gradle 9.3.1, Android Gradle plugin 9.1.0, Kotlin 2.4.0.

| Package | Version | Scope | License | Source |
|---|---|---|---|---|
| async | 2.13.1 | transitive | BSD-3-Clause | https://github.com/dart-lang/core/tree/main/pkgs/async |
| boolean_selector | 2.1.2 | transitive | BSD-3-Clause | https://github.com/dart-lang/tools/tree/main/pkgs/boolean_selector |
| characters | 1.4.1 | transitive | BSD-3-Clause | https://github.com/dart-lang/core/tree/main/pkgs/characters |
| clock | 1.1.3 | transitive | Apache-2.0 | https://github.com/dart-lang/tools/tree/main/pkgs/clock |
| collection | 1.19.1 | transitive | BSD-3-Clause | https://github.com/dart-lang/core/tree/main/pkgs/collection |
| fake_async | 1.3.3 | transitive | Apache-2.0 | https://github.com/dart-lang/test/tree/master/pkgs/fake_async |
| flutter | 0.0.0 | direct main | BSD-3-Clause | https://flutter.dev |
| flutter_lints | 6.0.0 | direct dev | BSD-3-Clause | https://github.com/flutter/packages/tree/main/packages/flutter_lints |
| flutter_test | 0.0.0 | direct dev | BSD-3-Clause | https://pub.dev/packages/flutter_test |
| leak_tracker | 11.0.2 | transitive | BSD-3-Clause | https://github.com/dart-lang/leak_tracker/tree/main/pkgs/leak_tracker |
| leak_tracker_flutter_testing | 3.0.10 | transitive | BSD-3-Clause | https://github.com/dart-lang/leak_tracker/tree/main/pkgs/leak_tracker_flutter_testing |
| leak_tracker_testing | 3.0.2 | transitive | BSD-3-Clause | https://github.com/dart-lang/leak_tracker/tree/main/pkgs/leak_tracker_testing |
| lints | 6.1.0 | transitive | BSD-3-Clause | https://github.com/dart-lang/core/tree/main/pkgs/lints |
| matcher | 0.12.20 | transitive | BSD-3-Clause | https://github.com/dart-lang/test/tree/master/pkgs/matcher |
| material_color_utilities | 0.13.0 | transitive | Apache-2.0 | https://github.com/material-foundation/material-color-utilities/tree/main/dart |
| meta | 1.19.0 | transitive | BSD-3-Clause | https://github.com/dart-lang/sdk/tree/main/pkg/meta |
| path | 1.9.1 | transitive | BSD-3-Clause | https://github.com/dart-lang/core/tree/main/pkgs/path |
| sky_engine | 0.0.0 | transitive | BSD-3-Clause + bundled engine notices | https://github.com/flutter/flutter/tree/c197ca5199e9ee5661e865596c9c07294dfab51c/engine |
| source_span | 1.10.2 | transitive | BSD-3-Clause | https://github.com/dart-lang/tools/tree/main/pkgs/source_span |
| stack_trace | 1.12.2 | transitive | BSD-3-Clause | https://github.com/dart-lang/tools/tree/main/pkgs/stack_trace |
| stream_channel | 2.1.4 | transitive | BSD-3-Clause | https://github.com/dart-lang/tools/tree/main/pkgs/stream_channel |
| string_scanner | 1.4.1 | transitive | BSD-3-Clause | https://github.com/dart-lang/tools/tree/main/pkgs/string_scanner |
| term_glyph | 1.2.2 | transitive | BSD-3-Clause | https://github.com/dart-lang/tools/tree/main/pkgs/term_glyph |
| test_api | 0.7.12 | transitive | BSD-3-Clause | https://github.com/dart-lang/test/tree/master/pkgs/test_api |
| vector_math | 2.4.4 | transitive | BSD-3-Clause | https://github.com/flutter/core-packages/tree/main/packages/vector_math |
| vm_service | 15.4.0 | transitive | BSD-3-Clause | https://github.com/dart-lang/sdk/tree/main/pkg/vm_service |

Bundled Flutter font notices: Material Icons (Apache-2.0), Roboto and
Roboto Condensed (Apache-2.0 in the SDK's supplied font artifacts), original
license texts in docs/licenses. Sources: https://github.com/google/material-design-icons
and https://github.com/googlefonts/roboto. Font artifacts are pinned by the Flutter SDK.

The sky_engine SDK LICENSE is a composite engine notice, not solely Apache-2.0.
Its full original text is retained in docs/licenses/sky_engine.txt (including
component-specific terms and attributions); the inventory preserves that distinction.

Session build-tool addition: Eclipse Temurin OpenJDK 21.0.13+9 full JDK, fetched via
https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse
(source https://github.com/adoptium/temurin21-binaries). License:
GPL-2.0-only WITH Classpath-exception-2.0, with bundled component notices retained
in the installed toolchain. Build-only, not committed or bundled in the app.
This replaces the environment's compiler-less Java runtime for Android builds;
commercial proprietary compilation is permitted by the toolchain terms.

## M1 model-independent slice

No new dependency, copied algorithm, model weights or external dataset is added.
`assets/fixtures/occlusion.json` and `test/fixtures/occlusion.expected.jsonl` are
original repository-authored synthetic annotations/evidence; no third-party asset
license or personal recording is involved. The IoU arithmetic and harness are
original implementation, not copied from a detector/tracker library.
MediaPipe runtime source (https://github.com/google-ai-edge/mediapipe) is identified
as Apache-2.0 but is **not installed or bundled**. This does not license separate
EfficientDet/MediaPipe weights. Model acceptance is blocked pending a verifiable
license accompanying a specific artifact and commercial redistribution review.
