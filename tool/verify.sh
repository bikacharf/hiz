#!/usr/bin/env bash
set -euo pipefail
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-pub
flutter test --no-pub
python3 tool/check_licenses.py
flutter build apk --debug --no-pub
