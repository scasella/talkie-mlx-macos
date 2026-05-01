#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-0.1.0}"
DISPLAY_NAME="Talkie Cabinet"
APP_NAME="TalkieCabinet"
BUNDLE_ID="dev.casella.TalkieCabinet"
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Stephen Casella (9ZJC9RDWN7)}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$ROOT_DIR/release"
APP_BUNDLE="$DIST_DIR/$DISPLAY_NAME.app"
DMG="$RELEASE_DIR/Talkie-Cabinet-v$VERSION.dmg"
DMG_STAGE="$RELEASE_DIR/dmg-stage"
SIGN=0
NOTARIZE=0

usage() {
  echo "usage: $0 [--sign] [--notarize]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sign)
      SIGN=1
      ;;
    --notarize)
      SIGN=1
      NOTARIZE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
  shift
done

VERSION="$VERSION" "$ROOT_DIR/scripts/build_app.sh" >/dev/null
mkdir -p "$RELEASE_DIR"

if [[ "$SIGN" == "1" ]]; then
  codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP_BUNDLE"
  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
fi

rm -f "$DMG"
rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"
cp -R "$APP_BUNDLE" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"

hdiutil create \
  -volname "$DISPLAY_NAME" \
  -srcfolder "$DMG_STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

if [[ "$SIGN" == "1" ]]; then
  codesign --force --timestamp --sign "$IDENTITY" "$DMG"
  codesign --verify --verbose=2 "$DMG"
fi

if [[ "$NOTARIZE" == "1" ]]; then
  if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
  elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    xcrun notarytool submit "$DMG" \
      --apple-id "$APPLE_ID" \
      --team-id "$APPLE_TEAM_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --wait
  else
    echo "Notarization requested but no NOTARYTOOL_PROFILE or Apple ID env vars are set." >&2
    exit 2
  fi

  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
fi

(cd "$RELEASE_DIR" && shasum -a 256 "$(basename "$DMG")") > "$DMG.sha256"

if [[ "$NOTARIZE" == "1" ]]; then
  spctl --assess --type execute --verbose=4 "$APP_BUNDLE"
elif [[ "$SIGN" == "1" ]]; then
  if ! spctl --assess --type execute --verbose=4 "$APP_BUNDLE"; then
    echo "Signed app is not notarized yet; Gatekeeper assessment is expected to fail before --notarize." >&2
  fi
fi

cat <<EOF
Built release artifact:
$DMG
$DMG.sha256
EOF
