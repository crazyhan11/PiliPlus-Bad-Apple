#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="PiliPlus"
BUNDLE_ID="com.example.piliplus"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-$(command -v flutter || true)}"
if [[ -z "$FLUTTER_BIN" ]]; then
  echo "flutter was not found; set FLUTTER_BIN to the Flutter executable" >&2
  exit 1
fi
FLUTTER_ROOT="$(cd "$(dirname "$FLUTTER_BIN")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build/macos-arm64"
BUILT_APP="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"
APP_BUNDLE="${PILIPLUS_MACOS_OUTPUT:-$PROJECT_DIR/outputs/PiliPlus-Bad-Apple-macOS-arm64.app}"
CUSTOM_FLUTTER_FRAMEWORK="${PILIPLUS_FLUTTER_FRAMEWORK:-$FLUTTER_ROOT/engine/src/out/host_release_arm64/FlutterMacOS.framework}"
APP_FLUTTER_FRAMEWORK="$APP_BUNDLE/Contents/Frameworks/FlutterMacOS.framework"

export RUBYOPT="-rlogger"
export PATH="$(dirname "$FLUTTER_BIN"):$PATH"
export FLUTTER_SUPPRESS_ANALYTICS=true
export COCOAPODS_DISABLE_STATS=true

test -f "$CUSTOM_FLUTTER_FRAMEWORK/FlutterMacOS"
/usr/bin/lipo -verify_arch arm64 "$CUSTOM_FLUTTER_FRAMEWORK/FlutterMacOS"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

cd "$PROJECT_DIR"
"$FLUTTER_BIN" pub get --offline
(cd macos && pod install)
xcodebuild \
  -workspace macos/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

rm -rf "$APP_BUNDLE"
/usr/bin/ditto "$BUILT_APP" "$APP_BUNDLE"
rm -rf "$APP_FLUTTER_FRAMEWORK"
/usr/bin/ditto "$CUSTOM_FLUTTER_FRAMEWORK" "$APP_FLUTTER_FRAMEWORK"
/usr/bin/cmp "$CUSTOM_FLUTTER_FRAMEWORK/FlutterMacOS" "$APP_FLUTTER_FRAMEWORK/FlutterMacOS"
/usr/bin/codesign --force --deep --sign - "$APP_BUNDLE"

open_app() {
  /usr/bin/env \
    -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u NO_PROXY \
    -u http_proxy -u https_proxy -u all_proxy -u no_proxy \
    /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    /usr/bin/env \
      -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u NO_PROXY \
      -u http_proxy -u https_proxy -u all_proxy -u no_proxy \
      /usr/bin/lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    "$PROJECT_DIR/tool/verify_macos_igl.sh" "$APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
