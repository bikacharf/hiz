# Third-party components — M0

No detector, weights, dataset, backend, analytics, purchases, or camera dependency is bundled.
All package dependencies (including transitive development packages) are enumerated in
`docs/DEPENDENCIES.md` against `pubspec.lock`. `tool/check_licenses.py` fails on drift.
Licenses are retained by the Flutter SDK/pub cache and Flutter's generated LicenseRegistry.
Redistribution must retain the applicable copyright and license notices.

| Component | Pin | Source | License | Commercial-use review |
|---|---|---|---|---|
| Flutter SDK and flutter/flutter_test | 3.47.9, c197ca5199e9ee5661e865596c9c07294dfab51c | https://github.com/flutter/flutter | BSD-3-Clause | Permissive; preserve notices |
| Flutter sky_engine | Flutter 3.47.9 engine 89c39edfdf | https://github.com/flutter/flutter | Engine aggregate notices; exact hash in docs/DEPENDENCIES.md | Preserve upstream aggregate; no separately selected engine component |
| Dart SDK | 3.13.7 (Flutter bundled) | https://github.com/dart-lang/sdk | BSD-3-Clause | Permissive; preserve notices |
| Dart pub packages | Exact versions in docs/DEPENDENCIES.md | https://pub.dev | Per-package inventory | Only BSD-3-Clause, MIT, Apache-2.0 accepted |
| Gradle wrapper/build tooling | Generated Android pins | https://gradle.org | Apache-2.0 | Build only; preserve wrapper notices |
| Android Gradle plugin / Kotlin plugin | Generated Android pins | https://developer.android.com/build / https://github.com/JetBrains/kotlin | Apache-2.0 | Build only |
| Android platform SDK | compile SDK from pinned Flutter | https://developer.android.com/studio/terms | Android SDK License Agreement | Build-only platform tool; CI accepts SDK terms, no SDK redistribution |
| Apple SDK | Supplied by Xcode; not bundled | https://developer.apple.com/support/terms/ | Apple SDK agreement | Mac validation required; no Apple SDK redistribution |
| GitHub Actions checkout/setup-java, subosito/flutter-action | v4 / v4 / v2 | https://github.com/actions/checkout / https://github.com/actions/setup-java / https://github.com/subosito/flutter-action | MIT | CI only; preserve upstream notices |

Application code remains proprietary; this inventory does not grant rights to application code.
No GPL/AGPL or unclear-license runtime component is accepted. SDK internal build tools are
not app dependencies. No copied algorithm or external artwork is included.
