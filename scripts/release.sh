#!/bin/bash
# Builds a free, direct-download release of Bean:
#   tests -> Release archive -> Developer ID export -> notarize + staple app
#   -> DMG -> notarize + staple DMG -> verify
#
# Usage:
#   scripts/release.sh                 full release (needs a notarytool keychain profile)
#   scripts/release.sh --skip-notarize signed DMG only, for local testing
#
# One-time setup (by the maintainer; stores an app-specific password in the keychain):
#   xcrun notarytool store-credentials BeanNotary --apple-id <apple-id> --team-id <TEAM_ID>
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

# Maintainer-specific values live in Config/Local.env (git-ignored); see Config/Local.env.example.
[[ -f Config/Local.env ]] && source Config/Local.env
: "${TEAM_ID:?Set TEAM_ID in Config/Local.env (your Apple Developer Team ID)}"
PROFILE="${NOTARY_PROFILE:-BeanNotary}"
SKIP_NOTARIZE=0
[[ "${1:-}" == "--skip-notarize" ]] && SKIP_NOTARIZE=1

VERSION="$(grep -m1 'MARKETING_VERSION' Bean.xcodeproj/project.pbxproj | sed -E 's/.*= ([^;]+);/\1/')"
OUT="build/release"
ARCHIVE="$OUT/Bean.xcarchive"
EXPORT="$OUT/export"
DMG="$OUT/Bean-$VERSION.dmg"

if [[ $SKIP_NOTARIZE -eq 0 ]] && ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
  echo "No notarytool keychain profile named '$PROFILE'. Create it once with:" >&2
  echo "  xcrun notarytool store-credentials $PROFILE --apple-id <apple-id> --team-id $TEAM_ID" >&2
  echo "or run with --skip-notarize for a local, un-notarized build." >&2
  exit 2
fi

echo "==> Unit tests"
swift test --package-path BeanCore

echo "==> Archive $VERSION (Release, universal)"
rm -rf "$OUT"; mkdir -p "$OUT"
xcodebuild archive -project Bean.xcodeproj -scheme Bean -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" -derivedDataPath "$OUT/DerivedData" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM="$TEAM_ID" PROVISIONING_PROFILE_SPECIFIER= \
  | grep -E "error|warning: |ARCHIVE" || true
[[ -d "$ARCHIVE" ]] || { echo "Archive failed" >&2; exit 1; }

echo "==> Export (Developer ID)"
EXPORT_OPTIONS="$OUT/ExportOptions.plist"
sed "s/TEAM_ID_PLACEHOLDER/$TEAM_ID/" Config/ExportOptions-DeveloperID.plist > "$EXPORT_OPTIONS"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
  -exportOptionsPlist "$EXPORT_OPTIONS" | grep -E "error|EXPORT" || true
APP="$EXPORT/Bean.app"
codesign --verify --deep --strict --verbose=2 "$APP"
SIGNATURE="$(codesign -dv --verbose=4 "$APP" 2>&1)"
[[ "$SIGNATURE" == *"(runtime)"* ]] || { echo "Hardened Runtime missing" >&2; exit 1; }
[[ "$SIGNATURE" == *"Timestamp="* ]] || { echo "Secure timestamp missing" >&2; exit 1; }
[[ "$SIGNATURE" == *"Authority=Developer ID Application"* ]] || { echo "Not signed with Developer ID" >&2; exit 1; }

if [[ $SKIP_NOTARIZE -eq 0 ]]; then
  # Notarize and staple the app itself, so it carries its ticket after being
  # dragged out of the DMG and can pass Gatekeeper on a Mac with no network.
  echo "==> Notarize app (waits for Apple)"
  ditto -c -k --keepParent "$APP" "$OUT/Bean-app.zip"
  xcrun notarytool submit "$OUT/Bean-app.zip" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  rm -f "$OUT/Bean-app.zip"
fi

echo "==> DMG"
STAGE="$OUT/dmg"; mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Bean.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Bean" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
codesign --sign "Developer ID Application" --timestamp "$DMG"

if [[ $SKIP_NOTARIZE -eq 1 ]]; then
  echo "==> Skipped notarization. $DMG is signed but NOT notarized; Gatekeeper will warn on other Macs."
  exit 0
fi

echo "==> Notarize DMG (waits for Apple)"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl -a -t open --context context:primary-signature -vv "$DMG"

shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "==> Done: $DMG (notarized and stapled). Attach it and the .sha256 to a GitHub Release."
