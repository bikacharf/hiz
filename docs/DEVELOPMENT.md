# M0 development shell

## Toolchain and identifiers

Pinned Flutter 3.47.9 stable (revision c197ca5199e9ee5661e865596c9c07294dfab51c),
Dart 3.13.7, Temurin JDK 21.0.13+9 (CI and final Android attempt). Generated Android Gradle/Kotlin versions are pinned in
android/settings.gradle.kts and android/gradle/wrapper/gradle-wrapper.properties.
Android application ID: `com.example.hiz_olcer`; iOS bundle ID:
`com.example.hizOlcer` (test bundle: `com.example.hizOlcer.RunnerTests`). These are placeholders; replace before
signing/distribution. No signing credentials are required or committed.

## Clean Linux setup

Allow at least 12 GiB of free toolchain/build space.
Install git, curl, xz-utils, unzip, Python 3, a full Java 21 JDK (including javac) and the Android command-line
SDK from their official distributions. Install Android SDK versions requested by
the generated Gradle files and accept the Android SDK license after reviewing it.
Export ANDROID_HOME and add its platform-tools and cmdline-tools/latest/bin to PATH.

Download https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.9-stable.tar.xz
and verify SHA-256 `25ed8c3c29d51a7353f2a944310b478af8214920639524b19c50a19e6c044c5a`.
Extract outside the repository and add flutter/bin to PATH. Preserve proxy and CA
configuration. In Codex Cloud every network command must explicitly request
`with_additional_permissions` with `additional_permissions.network.enabled: true`.
This includes setup, pub resolution, Gradle builds, and git push.

```
flutter --version
java -version
javac -version
flutter doctor -v
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
python3 tool/check_licenses.py
flutter build apk --debug --no-pub
```

Run `flutter run` on an attached Android device to inspect the labeled static UI.
No camera permission, preview, inference, measurement or persistence is implemented.
The native Kotlin/Swift entry points are generated hosts. Future performance code
must implement the separate typed contracts; no native channel simulates results.
Quality signals are observable gates, never an accuracy score. Unknown gates fail
closed. Thresholds and methods remain unvalidated; sufficient gates alone do not
prove measurement accuracy.

## Mac/Xcode validation — REQUIRED, NOT VERIFIED

On a Mac install the pinned Flutter SDK and a compatible Xcode with iOS SDK;
record `xcodebuild -version`, `xcrun --sdk iphoneos --show-sdk-version`,
`swift --version`, and `flutter doctor -v`. Select Xcode with xcode-select if needed.
Run pub resolution and all shared checks above, then:

```
flutter build ios --simulator --debug --no-pub
flutter build ios --debug --no-codesign --no-pub
flutter devices
flutter run -d <ios-simulator-id>
```

Check all routes and prototype disclosures. Record exact Xcode/iOS versions and
results in STATUS.md. Device signing, camera behavior, performance and thermal
validation need a physical iPhone in later milestones. Linux results establish no
iOS compilation or device behavior.

## Writable tool state in restricted Cloud sessions

Keep SDKs/caches outside the repository. This session uses /workspace/toolchains.
Do not replace HOME. Set these command-scoped variables when the user directory
is read-only:

```
export XDG_CONFIG_HOME=/workspace/toolchains/config
export ANALYZER_STATE_LOCATION_OVERRIDE=/workspace/toolchains/analyzer
export PUB_CACHE=/workspace/toolchains/pub-cache
export ANDROID_HOME=/workspace/toolchains/android-sdk
export ANDROID_USER_HOME=/workspace/toolchains/android-user
export GRADLE_USER_HOME=/workspace/toolchains/gradle
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
```

Android command-line tools 19.0 were installed from Google's
commandlinetools-linux-13114758_latest.zip. Install platform-tools,
platforms;android-36 and build-tools;36.0.0. Flutter pins NDK 28.2.13676358.
For a proxy-based cloud, pass sdkmanager --proxy=http --proxy_host=proxy
--proxy_port=8080, and configure Gradle's command-local user properties with
systemProp.http.proxyHost, http.proxyPort, https.proxyHost, https.proxyPort.
Use the inherited proxy's host/port; these session values are proxy:8080.
Do not disable certificate verification. Flutter tests need local loopback socket
permission, so they also use the explicit network-enabled execution permission.

`tool/verify.sh` runs the complete gate sequence and stops at the first failure.
Invoke it with explicit network permission in Cloud because pub, loopback tests
and Gradle may use the network.

For a new Linux machine with the prerequisites above, run
`HIZ_TOOLCHAIN_DIR=/your/writable/toolchains tool/setup_linux.sh` to download the
pinned SDKs. This is an interactive license-review step, not an automatic license
acceptance. In Cloud the invocation itself must carry the explicit network grant.
The helper supports an HTTP proxy specified as host:port without credentials;
for other proxy formats configure sdkmanager per the official Android tools docs.

This small Cloud instance stores the session-only NDK and Flutter SDK on /tmp via SDK-path
symlinks to keep toolchain extraction within the available volumes. No repository
file or CI configuration depends on that session path.

A Java runtime alone is insufficient: verify javac exists. This session initially
had OpenJDK 21 JRE only; a separate Temurin 21 JDK was installed outside the repo.
Set JAVA_HOME to the full JDK and prepend its bin to PATH for the Android build.

For a separately downloaded JDK in this proxy-based Cloud environment, use the
system's configured CA trust store rather than disabling TLS verification.
The session's external GRADLE_USER_HOME/gradle.properties contains:

```
systemProp.javax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts
org.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=1G -Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts
org.gradle.workers.max=2
```

The same trustStore property is passed in JAVA_OPTS for the wrapper. These are
session settings, not portable repository defaults; use your host's trusted CA
configuration on other machines. Restart existing Gradle daemons after changing
JDK/trust settings. Do not disable TLS checks.

Final Android gate passed with Temurin 21.0.13+9 in 46.4 seconds. During the
final build TMPDIR=/workspace/toolchains/tmp kept compiler temporaries on the
volume with free space. See validation/android-build-final.txt for raw output.

After integration with existing M0 history, the final branch passed all 11 tests
and repeated the Android debug build in 4.1 seconds with cached tools.
