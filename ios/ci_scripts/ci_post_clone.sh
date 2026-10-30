#!/bin/bash
set -euo pipefail

# Xcode Cloud invokes this before resolving the workspace's Swift packages.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
cd "$PROJECT_ROOT"

: "${CI_BUILD_NUMBER:?CI_BUILD_NUMBER must be supplied by Xcode Cloud}"
if [[ ! "$CI_BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "error: CI_BUILD_NUMBER must be a positive integer." >&2
  exit 1
fi

# Use the same pinned SDK as local FVM builds, rather than a moving stable branch.
FLUTTER_VERSION="$(python3 -c 'import json; print(json.load(open(".fvmrc"))["flutter"])')"
if [[ ! "$FLUTTER_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: .fvmrc must pin an exact Flutter release." >&2
  exit 1
fi
if [[ -z "${FLUTTER_ROOT:-}" ]]; then
  FLUTTER_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/1panel-flutter.XXXXXX")"
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
fi
export FLUTTER_ROOT
if [[ ! -x "$FLUTTER_ROOT/bin/flutter" ]]; then
  echo "error: FLUTTER_ROOT does not contain an executable Flutter SDK." >&2
  exit 1
fi
export PATH="$FLUTTER_ROOT/bin:$PATH"
export FLUTTER_SUPPRESS_ANALYTICS=true
export COCOAPODS_DISABLE_STATS=true
export HOMEBREW_NO_AUTO_UPDATE=1

INSTALLED_VERSION="$(flutter --version --machine | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')"
if [[ "$INSTALLED_VERSION" != "$FLUTTER_VERSION" ]]; then
  echo "error: Expected Flutter $FLUTTER_VERSION, found $INSTALLED_VERSION." >&2
  exit 1
fi

# Runner already integrates FlutterGeneratedPluginSwiftPackage; some plugins
# still require CocoaPods. Prepare both before generating workspace inputs.
flutter precache --ios
if ! command -v pod >/dev/null 2>&1; then
  brew install cocoapods
fi
flutter pub get --enforce-lockfile
flutter build ios --release --config-only --no-codesign --no-pub \
  --build-number="$CI_BUILD_NUMBER"

# Catch dependency drift instead of silently building a different native graph.
git diff --exit-code -- pubspec.lock ios/Podfile.lock \
  ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved \
  ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

echo "Flutter $FLUTTER_VERSION is ready for Xcode Cloud (build $CI_BUILD_NUMBER)."
