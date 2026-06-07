#!/bin/bash

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
PROJECT_PATH="${PROJECT_PATH:-ygocdb.xcodeproj}"
SCHEME="${SCHEME:-ygocdb}"
CONFIGURATION="${CONFIGURATION:-Release}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/dist}"
ARCHIVE_BASENAME="${ARCHIVE_BASENAME:-${SCHEME}-$(date +%Y%m%d-%H%M%S)}"
ARCHIVE_DIR="${ARCHIVE_DIR:-$OUTPUT_DIR/archives}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ARCHIVE_DIR/${ARCHIVE_BASENAME}.xcarchive}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/${SCHEME}-unsigned-ipa-dd}"
IPA_PATH="${IPA_PATH:-$OUTPUT_DIR/${ARCHIVE_BASENAME}-unsigned.ipa}"
SKIP_ARCHIVE="${SKIP_ARCHIVE:-0}"

WORK_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR" "$ARCHIVE_DIR"

echo "==> Preparing unsigned IPA build"
echo "    root: $PROJECT_ROOT"
echo "    project: $PROJECT_PATH"
echo "    scheme: $SCHEME"
echo "    configuration: $CONFIGURATION"
echo "    archive: $ARCHIVE_PATH"
echo "    ipa: $IPA_PATH"
echo "    skip archive: $SKIP_ARCHIVE"

pushd "$PROJECT_ROOT" >/dev/null

if [ "$SKIP_ARCHIVE" != "1" ]; then
  xcodebuild archive \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    DEVELOPMENT_TEAM="" \
    COMPILER_INDEX_STORE_ENABLE=NO \
    archive
fi

if [ ! -d "$ARCHIVE_PATH" ]; then
  echo "ERROR: Archive not found: $ARCHIVE_PATH" >&2
  exit 1
fi

APP_PATH="$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -name "*.app" -print -quit)"

if [ -z "$APP_PATH" ]; then
  echo "ERROR: No .app found inside archive: $ARCHIVE_PATH" >&2
  exit 1
fi

APP_NAME="$(basename "$APP_PATH")"
PAYLOAD_DIR="$WORK_DIR/Payload"
COPIED_APP_PATH="$PAYLOAD_DIR/$APP_NAME"

mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$COPIED_APP_PATH"

rm -rf "$COPIED_APP_PATH/_CodeSignature"
rm -f "$COPIED_APP_PATH/embedded.mobileprovision"

(cd "$WORK_DIR" && /usr/bin/zip -qry "$IPA_PATH" Payload)

popd >/dev/null

echo "==> Verifying IPA contents"
IPA_LISTING="$("/usr/bin/unzip" -Z1 "$IPA_PATH")"
case "$IPA_LISTING" in
  *"Payload/$APP_NAME/"*)
    ;;
  *)
    echo "ERROR: IPA verification failed for $IPA_PATH" >&2
    exit 1
    ;;
esac

echo "ARCHIVE_PATH=$ARCHIVE_PATH"
echo "IPA_PATH=$IPA_PATH"
echo "APP_NAME=$APP_NAME"
echo "STATUS=success"
