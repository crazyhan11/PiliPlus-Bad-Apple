#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BUILDER_DIR="${LIBMPV_BUILDER_DIR:-$ROOT/.cache/libmpv-darwin-build}"
VERSION="${LIBMPV_VERSION:-v0.39.0-av1-vt}"
OUTPUT="build/output/libmpv-xcframeworks_${VERSION}_ios-universal-video-default.tar.gz"
FRAMEWORK_DIR="$ROOT/third_party/media-kit/libs/ios/media_kit_libs_ios_video/ios/Frameworks"

command -v cmake >/dev/null
command -v go >/dev/null
command -v meson >/dev/null
command -v nasm >/dev/null
command -v ninja >/dev/null

if [ ! -d "$BUILDER_DIR/.git" ]; then
  mkdir -p "$(dirname "$BUILDER_DIR")"
  git clone --depth 1 --branch v0.39.0 \
    https://github.com/gungun974/melodink-libmpv-darwin-build.git \
    "$BUILDER_DIR"
fi

cd "$BUILDER_DIR"
if git apply --check "$ROOT/tool/patches/ffmpeg-av1-videotoolbox.patch"; then
  git apply "$ROOT/tool/patches/ffmpeg-av1-videotoolbox.patch"
elif ! git apply --reverse --check "$ROOT/tool/patches/ffmpeg-av1-videotoolbox.patch"; then
  echo "The libmpv source is not compatible with the AV1 VideoToolbox patch." >&2
  exit 1
fi

GOPROXY="${GOPROXY:-https://goproxy.cn,direct}" \
  make VERSION="$VERSION" "$OUTPUT"

mkdir -p "$FRAMEWORK_DIR"
tar -xvf "$OUTPUT" --strip-components 1 -C "$FRAMEWORK_DIR"
