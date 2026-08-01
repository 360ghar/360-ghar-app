#!/usr/bin/env bash
# upload_ios_symbols.sh - collect & upload iOS dSYMs to Firebase Crashlytics.
#
# Why this exists (RCA: docs/dSYM_UPLOAD_RCA.md):
#   The Xcode archive's dSYMs folder only contains dSYMs for code compiled
#   locally (Runner, Flutter, App, native-assets frameworks). Prebuilt SwiftPM
#   binary artifacts (FirebaseAnalytics, GoogleAppMeasurement, MapLibre,
#   RecaptchaEnterpriseSDK, GoogleAdsOnDeviceConversion, ...) ship without
#   dSYMs, so App Store Connect reports "Upload Symbols Failed" for their UUIDs
#   (non-fatal warning) and Crashlytics cannot symbolize frames in them.
#
#   This tool guarantees every dSYM that DOES exist is found and uploaded to
#   Crashlytics, and prints a per-framework coverage report so the expected
#   gaps are visible instead of silent.
#
# Usage:
#   ./tool/upload_ios_symbols.sh [--dry-run] [path/to.xcarchive]
#
#   Default archive: newest *.xcarchive in ~/Library/Developer/Xcode/Archives.
#
# Exit code 0 even when coverage gaps exist (they are non-fatal by design);
# non-zero only when collection or the Crashlytics upload itself fails.
# NOTE: no `set -u` -- macOS ships bash 3.2, where expanding an empty array
# under `-u` raises "unbound variable".
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GSP="$ROOT_DIR/ios/Runner/GoogleService-Info.plist"

DRY_RUN=0
ARCHIVE=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) ARCHIVE="$arg" ;;
  esac
done

if [ -z "$ARCHIVE" ]; then
  ARCHIVE="$(ls -td "$HOME"/Library/Developer/Xcode/Archives/*/*.xcarchive 2>/dev/null | head -1 || true)"
  if [ -z "$ARCHIVE" ]; then
    echo "error: no xcarchive found; pass one explicitly." >&2
    exit 1
  fi
  echo "Using newest archive: $ARCHIVE"
fi
if [ ! -d "$ARCHIVE" ]; then
  echo "error: not an xcarchive directory: $ARCHIVE" >&2
  exit 1
fi

# --- Locate the app inside the archive --------------------------------------
APP="$(find "$ARCHIVE/Products/Applications" -maxdepth 1 -name '*.app' -type d 2>/dev/null | head -1 || true)"
if [ -z "$APP" ]; then
  echo "error: no .app found inside $ARCHIVE/Products/Applications" >&2
  exit 1
fi
echo "Archive: $ARCHIVE"
echo "App:     $APP"
echo

uuid_of() { # <binary-or-dsym> -> one UUID per line
  xcrun dwarfdump --uuid "$1" 2>/dev/null | sed -n 's/^UUID: \([0-9A-F-]*\).*/\1/p'
}

contains() { # needle haystack...
  local needle="$1"
  shift
  for item in "$@"; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

# --- Map every embedded binary to its UUIDs ---------------------------------
EMBED_UUIDS=()
EMBED_NAMES=()

add_embed() { # display-name binary-path
  local name="$1" bin="$2" u
  for u in $(uuid_of "$bin"); do
    if ! contains "$u" "${EMBED_UUIDS[@]}"; then
      EMBED_UUIDS+=("$u")
      EMBED_NAMES+=("$name")
    fi
  done
}

while IFS= read -r -d '' fwdir; do
  fwname="$(basename "$fwdir")"
  add_embed "$fwname" "$fwdir/${fwname%.framework}"
done < <(find "$APP" -type d -name '*.framework' -print0 2>/dev/null)

main_bin="$(find "$APP" -maxdepth 1 -type f -perm -111 2>/dev/null | head -1 || true)"
if [ -n "$main_bin" ]; then
  add_embed "$(basename "$APP")" "$main_bin"
fi

if [ "${#EMBED_UUIDS[@]}" -eq 0 ]; then
  echo "error: could not extract any UUIDs from $APP" >&2
  exit 1
fi

# --- Collect candidate dSYMs from the archive + DerivedData -----------------
CANDIDATES=()
while IFS= read -r -d '' d; do CANDIDATES+=("$d"); done \
  < <(find "$ARCHIVE/dSYMs" -maxdepth 1 -type d -name '*.dSYM' -print0 2>/dev/null || true)
while IFS= read -r -d '' d; do CANDIDATES+=("$d"); done \
  < <(find "$HOME/Library/Developer/Xcode/DerivedData" "$ROOT_DIR/build/ios" \
       -type d -name '*.dSYM' -path '*/Build/Products/*' -print0 2>/dev/null || true)

COLLECTED_UUIDS=()
COLLECTED_PATHS=()
for d in "${CANDIDATES[@]}"; do
  for u in $(uuid_of "$d"); do
    if contains "$u" "${EMBED_UUIDS[@]}" && ! contains "$u" "${COLLECTED_UUIDS[@]}"; then
      COLLECTED_UUIDS+=("$u")
      COLLECTED_PATHS+=("$d")
    fi
  done
done

# --- Report ----------------------------------------------------------------
echo "Embedded binaries: ${#EMBED_UUIDS[@]} UUIDs, collected dSYMs: ${#COLLECTED_UUIDS[@]}"
echo
for u in "${COLLECTED_UUIDS[@]}"; do
  name="?"
  for i in "${!EMBED_UUIDS[@]}"; do
    if [ "${EMBED_UUIDS[$i]}" = "$u" ]; then name="${EMBED_NAMES[$i]}"; break; fi
  done
  echo "  [ok] $name  $u"
done
echo
if [ "${#EMBED_UUIDS[@]}" -gt "${#COLLECTED_UUIDS[@]}" ]; then
  echo "Coverage gaps (no dSYM exists for these UUIDs):"
  for i in "${!EMBED_UUIDS[@]}"; do
    u="${EMBED_UUIDS[$i]}"
    if ! contains "$u" "${COLLECTED_UUIDS[@]}"; then
      case "${EMBED_NAMES[$i]}" in
        FirebaseAnalytics.framework|GoogleAppMeasurement.framework|GoogleAppMeasurementIdentitySupport.framework|MapLibre.framework|RecaptchaEnterpriseSDK.framework|GoogleAdsOnDeviceConversion.framework)
          echo "  [expected] ${EMBED_NAMES[$i]}  $u  (prebuilt SwiftPM binary - no upstream dSYM; non-fatal)" ;;
        *)
          echo "  [missing] ${EMBED_NAMES[$i]}  $u" ;;
      esac
    fi
  done
  echo
  echo "Note: 'Upload Symbols Failed' warnings from App Store Connect for the"
  echo "expected gaps above are non-fatal - the build still uploads/processes."
  echo "See docs/dSYM_UPLOAD_RCA.md."
  echo
fi

# --- Upload to Crashlytics --------------------------------------------------
if [ "${#COLLECTED_UUIDS[@]}" -eq 0 ]; then
  echo "No dSYMs to upload."
  exit 0
fi

UPLOAD_SYMBOLS="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
  -path '*firebase-ios-sdk/Crashlytics/upload-symbols' -type f 2>/dev/null | head -1 || true)"
if [ -z "$UPLOAD_SYMBOLS" ]; then
  echo "error: Crashlytics upload-symbols not found under DerivedData." >&2
  echo "       Archive once via Xcode (so SwiftPM checkouts exist), or install" >&2
  echo "       the flutterfire CLI: dart pub global activate flutterfire_cli" >&2
  exit 1
fi
if [ ! -f "$GSP" ]; then
  echo "error: missing $GSP (required for Crashlytics upload)" >&2
  exit 1
fi

STAGING="$(mktemp -d -t ghar360_dsyms)"
trap 'rm -rf "$STAGING"' EXIT
for p in "${COLLECTED_PATHS[@]}"; do
  [ -e "$STAGING/$(basename "$p")" ] || cp -R "$p" "$STAGING/"
done

if [ "$DRY_RUN" = 1 ]; then
  echo "[dry-run] would run:"
  echo "  \"$UPLOAD_SYMBOLS\" -gsp \"$GSP\" -p ios \"$STAGING\""
  ls -1 "$STAGING"
  exit 0
fi

echo "Uploading ${#COLLECTED_UUIDS[@]} dSYM UUIDs to Crashlytics..."
"$UPLOAD_SYMBOLS" -gsp "$GSP" -p ios "$STAGING"
echo "Done."

