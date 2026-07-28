#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
APP_BUNDLE="${1:-$WORKSPACE_DIR/outputs/PiliPlus-Bad-Apple-macOS-arm64.app}"
SAMPLE_VIDEO="${2:-$PROJECT_DIR/third_party/media-kit/video_player_media_kit/example/assets/Butterfly-209.mp4}"
AUDIO_SAMPLE="$PROJECT_DIR/third_party/media-kit/video_player_media_kit/example/assets/Audio.mp3"
FALLBACK_VIDEO="/System/Library/CoreServices/ControlCenter.app/Contents/Resources/BentoGalleryIntroduction.mov"
P010_VIDEO="/System/Library/Desktop Pictures/.wallpapers/macOS Beta/macOS Beta.mov"
HDR_VIDEO="$WORKSPACE_DIR/test-assets/PE2_Leopard_4K.mkv"
FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"
BUILD_FRAMEWORKS_DIR="$PROJECT_DIR/build/macos-arm64/DerivedData/Build/Products/Release"
MPV_HEADERS="$PROJECT_DIR/third_party/media-kit/libs/macos/media_kit_libs_macos_video/macos/Frameworks/Mpv.xcframework/macos-arm64/Mpv.framework/Versions/A/Headers"
SMOKE_TMP="$(mktemp -d "${TMPDIR:-/tmp}/piliplus-macos-igl.XXXXXX")"
SMOKE_BIN="$SMOKE_TMP/macos_igl_smoke"

cleanup() {
  rm -rf "$SMOKE_TMP"
}
trap cleanup EXIT

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "macOS IGL smoke: app bundle not found: $APP_BUNDLE" >&2
  exit 1
fi

xcrun clang++ \
  -std=c++17 \
  -fobjc-arc \
  -fblocks \
  -mmacosx-version-min=14.0 \
  -I "$MPV_HEADERS" \
  -F "$BUILD_FRAMEWORKS_DIR" \
  -F "$FRAMEWORKS_DIR" \
  -Wl,-rpath,"$FRAMEWORKS_DIR" \
  -framework Foundation \
  -framework CoreVideo \
  -framework FlutterMacOS \
  -framework Mpv \
  -framework media_kit_video \
  "$PROJECT_DIR/tool/macos_igl_smoke.mm" \
  -o "$SMOKE_BIN"

if [[ -f "$AUDIO_SAMPLE" ]]; then
  "$SMOKE_BIN" "$AUDIO_SAMPLE" audio
else
  echo "macOS audio smoke: sample not found: $AUDIO_SAMPLE" >&2
  exit 1
fi

if [[ -f "$SAMPLE_VIDEO" ]]; then
  "$SMOKE_BIN" "$SAMPLE_VIDEO" direct
else
  "$SMOKE_BIN"
fi

if [[ -f "$FALLBACK_VIDEO" && "$SAMPLE_VIDEO" != "$FALLBACK_VIDEO" ]]; then
  "$SMOKE_BIN" "$FALLBACK_VIDEO" fallback
fi

if [[ -f "$P010_VIDEO" && "$SAMPLE_VIDEO" != "$P010_VIDEO" ]]; then
  "$SMOKE_BIN" "$P010_VIDEO" direct
fi

if [[ -f "$HDR_VIDEO" && "$SAMPLE_VIDEO" != "$HDR_VIDEO" ]]; then
  "$SMOKE_BIN" "$HDR_VIDEO" direct
fi
