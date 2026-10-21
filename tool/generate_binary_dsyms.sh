#!/usr/bin/env bash
# Generate dSYMs for the prebuilt binary frameworks embedded in the app.
#
# Why this exists
# ---------------
# Six of our dependencies ship as SwiftPM *binary* targets (prebuilt dynamic
# .xcframeworks): FirebaseAnalytics, GoogleAppMeasurement,
# GoogleAppMeasurementIdentitySupport, GoogleAdsOnDeviceConversion,
# RecaptchaEnterpriseSDK and MapLibre. Xcode never compiles them, so it never
# emits a dSYM for them, and the vendors ship none inside the artifacts
# (verified: no *.dSYM and no DebugSymbolsPath in any downloaded xcframework).
# The archive's dSYMs/ folder therefore lacks their UUIDs and App Store Connect
# reports "Upload Symbols Failed - the archive did not include a dSYM for X".
#
# `dsymutil` can still build a valid dSYM straight from a stripped dylib: the
# output carries the binary's real LC_UUID, which is what Apple and Crashlytics
# match on, plus whatever symbol table survives stripping.
#   - MapLibre keeps its symbol table -> ~2900 symbols, real function-level
#     symbolication of the map screen (our largest third-party crash surface).
#   - The five Google frameworks are fully stripped (0 symbols) -> the dSYM is a
#     UUID-matching container only. It clears the warning; it cannot add
#     symbolication that the vendor binary does not contain.
#
# Usage
#   generate_binary_dsyms.sh                     # from an Xcode build phase
#   generate_binary_dsyms.sh <App.app> <out-dir> # standalone / against an archive
#
# Never fails the build: symbol generation is best-effort by design, so a
# problem here degrades symbolication instead of blocking a release. It still
# reports every action, because a silent no-op is how the previous dSYM bug hid.

set -uo pipefail

APP_PATH="${1:-}"
DSYM_OUT="${2:-}"

if [ -z "$APP_PATH" ]; then
  APP_PATH="${TARGET_BUILD_DIR:-}/${WRAPPER_NAME:-}"
fi
if [ -z "$DSYM_OUT" ]; then
  DSYM_OUT="${DWARF_DSYM_FOLDER_PATH:-}"
fi

label="binary-dsyms"

if [ ! -d "$APP_PATH" ]; then
  echo "warning: $label: app bundle not found at '$APP_PATH'; skipping dSYM generation" >&2
  exit 0
fi
if [ -z "$DSYM_OUT" ]; then
  echo "warning: $label: no dSYM output directory (DWARF_DSYM_FOLDER_PATH unset); skipping" >&2
  exit 0
fi
if [ ! -d "$APP_PATH/Frameworks" ]; then
  echo "note: $label: no embedded frameworks in '$APP_PATH'; nothing to do"
  exit 0
fi

mkdir -p "$DSYM_OUT" 2>/dev/null || true

uuids_of() {
  xcrun dwarfdump --uuid "$1" 2>/dev/null | awk '{print $2}'
}

# UUIDs already covered by dSYMs Xcode produced (Runner, Flutter, App, ...).
# Matching on UUID rather than filename means a stale dSYM gets regenerated.
covered=" "
for existing in "$DSYM_OUT"/*.dSYM; do
  [ -d "$existing" ] || continue
  for u in $(uuids_of "$existing"); do
    covered="${covered}${u} "
  done
done

generated=0
skipped=0
failed=0

for framework in "$APP_PATH"/Frameworks/*.framework; do
  [ -d "$framework" ] || continue
  name="$(basename "$framework" .framework)"

  binary="$framework/$name"
  if [ ! -f "$binary" ]; then
    # Fall back to the declared executable when it does not match the dir name.
    executable="$(/usr/libexec/PlistBuddy -c "Print CFBundleExecutable" \
      "$framework/Info.plist" 2>/dev/null || true)"
    binary="$framework/${executable}"
  fi
  [ -f "$binary" ] || continue

  binary_uuids="$(uuids_of "$binary")"
  [ -n "$binary_uuids" ] || continue

  needs_dsym=0
  for u in $binary_uuids; do
    case "$covered" in
      *" $u "*) ;;
      *) needs_dsym=1 ;;
    esac
  done

  if [ "$needs_dsym" -eq 0 ]; then
    skipped=$((skipped + 1))
    continue
  fi

  out="$DSYM_OUT/$name.framework.dSYM"

  # Never clobber a dSYM Xcode compiled. A locally-built framework (App, Flutter,
  # objective_c) has full DWARF in its own dSYM; regenerating from the stripped
  # embedded binary would replace it with a symbol-table stub. The UUID check
  # above already skips those in a normal build -- these two guards make that
  # independent of build-phase ordering rather than dependent on it.
  if [ -d "$out" ]; then
    skipped=$((skipped + 1))
    continue
  fi
  found_elsewhere=""
  for dir in "${BUILT_PRODUCTS_DIR:-}" "${CONFIGURATION_BUILD_DIR:-}"; do
    [ -n "$dir" ] || continue
    [ -d "$dir/$name.framework.dSYM" ] && found_elsewhere="$dir/$name.framework.dSYM"
  done
  if [ -n "$found_elsewhere" ]; then
    echo "note: $label: $name already has a compiled dSYM at $found_elsewhere; leaving it alone"
    skipped=$((skipped + 1))
    continue
  fi
  # dsymutil warns "no debug symbols in executable" for these stripped binaries
  # and still writes a correct, UUID-matching dSYM. That warning is expected.
  if ! xcrun dsymutil "$binary" -o "$out" 2>/dev/null; then
    echo "warning: $label: dsymutil failed for $name; it will stay unsymbolized" >&2
    failed=$((failed + 1))
    rm -rf "$out"
    continue
  fi

  dwarf="$out/Contents/Resources/DWARF/$(basename "$binary")"
  symbol_count="$(xcrun nm -a "$dwarf" 2>/dev/null | wc -l | tr -d ' ')"
  echo "note: $label: generated $name.framework.dSYM (${symbol_count} symbols, uuid $(echo $binary_uuids | tr '\n' ' '))"
  generated=$((generated + 1))
done

echo "note: $label: ${generated} generated, ${skipped} already had dSYMs, ${failed} failed"
exit 0
