#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
APP_PATH="${ROOT_DIR}/build/ios/iphoneos/Runner.app"
OUTPUT_DIR="${ROOT_DIR}/dist"
OUTPUT_PATH="${OUTPUT_DIR}/PiliPlus-Bad-Apple-IGL-ios-arm64-unsigned.ipa"
STAGING_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${STAGING_DIR}"
}
trap cleanup EXIT

cd "${ROOT_DIR}"
if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  "${FLUTTER_BIN}" build ios --release --no-codesign
fi

mkdir -p "${STAGING_DIR}/Payload" "${OUTPUT_DIR}"
cp -R "${APP_PATH}" "${STAGING_DIR}/Payload/Runner.app"

while IFS= read -r binary; do
  if codesign --display "${binary}" >/dev/null 2>&1; then
    codesign --remove-signature "${binary}"
  fi
done < <(find "${STAGING_DIR}/Payload/Runner.app" -type f -perm -111)

find "${STAGING_DIR}/Payload/Runner.app" -type d -name _CodeSignature -prune -exec rm -rf {} +
find "${STAGING_DIR}/Payload/Runner.app" -name embedded.mobileprovision -delete

if codesign --display "${STAGING_DIR}/Payload/Runner.app" >/dev/null 2>&1; then
  echo "Refusing to package a signed Runner.app" >&2
  exit 1
fi

signed_binaries=0
while IFS= read -r binary; do
  if codesign --display "${binary}" >/dev/null 2>&1; then
    echo "Signed binary remains: ${binary}" >&2
    signed_binaries=$((signed_binaries + 1))
  fi
done < <(find "${STAGING_DIR}/Payload/Runner.app" -type f -perm -111)

if ((signed_binaries > 0)); then
  exit 1
fi

cd "${STAGING_DIR}"
rm -f "${OUTPUT_PATH}"
COPYFILE_DISABLE=1 zip -qry "${OUTPUT_PATH}" Payload

echo "Unsigned IPA: ${OUTPUT_PATH}"
shasum -a 256 "${OUTPUT_PATH}"
