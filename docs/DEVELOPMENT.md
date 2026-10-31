# M0 development shell

## Pinned tools and neutral identifiers

Flutter stable **3.47.9**, revision `c197ca5199e9ee5661e865596c9c07294dfab51c`,
bundles Dart **3.13.7**. Android CI uses Temurin JDK **17.0.17+10**, Ubuntu 24.04,
and the Android SDK supplied by that runner. Gradle, AGP and Kotlin versions are
pinned in the generated Android build files (Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0); transitive Dart versions are locked.
Runner patches/Android SDK packages are not a hermetic image pin.
Android application ID and iOS bundle ID `com.example.hiz` are placeholders.
Replace both before any release; no signing identity or production key is included.

## Clean Linux setup

Install git, curl, xz, unzip, Temurin JDK 17.0.17+10 with javac, and Android command-line tools.
Install Android SDK API 36, build-tools 36.0.0 and NDK 28.2.13676358.
Accept their licenses only when authorized under the Android SDK terms:

```sh
sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" "ndk;28.2.13676358"
```
Set ANDROID_HOME and JAVA_HOME to these local installations.

```sh
curl --fail --location -o flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.9-stable.tar.xz
printf '25ed8c3c29d51a7353f2a944310b478af8214920639524b19c50a19e6c044c5a  flutter.tar.xz\n' | sha256sum --check
tar -xf flutter.tar.xz
export PATH="$PWD/flutter/bin:$PATH"
flutter --version
flutter doctor -v
# From repository root:
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
python3 tool/check_licenses.py
flutter build apk --debug --no-pub
```

In managed Codex, EVERY command that can use the network (including Flutter setup,
pub resolution, precache, build/Gradle, doctor and push) must request
`with_additional_permissions` and `additional_permissions.network.enabled=true`.
For this workspace's read-only user directory, also set process-local variables:

```sh
export XDG_CONFIG_HOME=/workspace/toolchains/config
export PUB_CACHE=/workspace/toolchains/pub-cache
export DART_DATA_HOME=/workspace/toolchains/dart-data
export ANALYZER_STATE_LOCATION_OVERRIDE=/workspace/toolchains/analyzer
export FLUTTER_SUPPRESS_ANALYTICS=true
export DASH__SUPPRESS_ANALYTICS=true
```

Do not disable inherited proxies or TLS trust. Default execution permissions caused
EPERM on proxy:8080/8088; explicit command-level network permission restored access.
Metadata source: https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json.

## Platform seams

Dart `lib/domain/contracts.dart` defines capture/detection/tracking, camera motion,
scale, speed, quality and evidence boundaries. Native Android Kotlin and iOS Swift
runners are generated shells only. Future capture must supply native monotonic
capture timestamps and lens/zoom metadata; frame pixel transport and platform
channels are deferred to M1/M2. No platform seam is mocked as a working camera.
Quality thresholds are provisional engineering checks, not accuracy estimates.
Evidence and candidate containers are immutable; no persistence or upload is wired.

## Mac/Xcode verification — not performed on Linux

Use Flutter 3.47.9 on a Mac with Xcode and the matching iOS SDK installed.
Record `sw_vers`, `xcodebuild -version`, `flutter doctor -v` in validation evidence.

```sh
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build ios --simulator --debug --no-pub
open ios/Runner.xcworkspace
```

Select an installed simulator, run Runner, and check Camera/History/Profile
navigation and Turkish text at small display sizes. Then configure a development
team locally and run on a named physical iPhone. Do not commit signing keys.
Camera permissions, live capture, performance, tracking, speed and accuracy remain
unimplemented/unverified regardless of successful shell compilation.
