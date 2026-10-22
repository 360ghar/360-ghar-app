#!/usr/bin/env bash
# Usage: verify_ios_release.sh [--fix] [path/to/Runner.app]
#
# --fix repairs the one thing that is routinely and legitimately broken: the
# generated SwiftPM plugin manifest, which `flutter pub get` rewrites to
# .iOS("13.0") every time (hardcoded in flutter_tools). Everything else is
# checked only, never touched.
#
# VERIFY_SKIP_DART_DEFINES=1 skips the baked dart-defines check (CI has none).
set -euo pipefail

FIX_MODE=""
if [ "${1:-}" = "--fix" ]; then
  FIX_MODE="fix"
  shift
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_PLIST="$ROOT_DIR/ios/Runner/Info.plist"
PRIVACY_MANIFEST="$ROOT_DIR/ios/Runner/PrivacyInfo.xcprivacy"
APP_FRAMEWORK_INFO="$ROOT_DIR/ios/Flutter/AppFrameworkInfo.plist"
PROJECT_PBXPROJ="$ROOT_DIR/ios/Runner.xcodeproj/project.pbxproj"
PUBSPEC="$ROOT_DIR/pubspec.yaml"
GENERATED_PACKAGE="$ROOT_DIR/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
GENERATED_XCCONFIG="$ROOT_DIR/ios/Flutter/Generated.xcconfig"

# Highest build number already uploaded to App Store Connect. Raise it after each upload.
# The pubspec build number must be greater, or Transporter rejects the upload.
LAST_SUBMITTED_BUILD=17

# The canonical deployment target comes from project.pbxproj. AppFrameworkInfo.plist
# and the generated SwiftPM plugin package must match it (Firebase requires iOS 15.0).
EXPECTED_DEPLOYMENT_TARGET="$(grep -o 'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*;' "$PROJECT_PBXPROJ" 2>/dev/null | head -1 | grep -o '[0-9.]*' || true)"
EXPECTED_DEPLOYMENT_TARGET="${EXPECTED_DEPLOYMENT_TARGET:-15.0}"

# Crashlytics dSYM upload tooling: the Run Script phase in project.pbxproj needs
# either the `flutterfire` CLI or the SwiftPM-checkout Crashlytics tool. Without
# one of them, crashes go unsymbolized (and the phase used to silently no-op).
# Fail fast here instead.
if ! command -v flutterfire >/dev/null 2>&1; then
  UPLOAD_SYMBOLS="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
    -path '*firebase-ios-sdk/Crashlytics/upload-symbols' -type f 2>/dev/null | head -1 || true)"
  if [ -z "$UPLOAD_SYMBOLS" ]; then
    echo "FAIL: Crashlytics dSYM upload tooling is unavailable - no 'flutterfire' CLI and no SwiftPM-checkout upload-symbols under DerivedData." >&2
    echo "      Install it: dart pub global activate flutterfire_cli" >&2
    echo "      (or archive once via Xcode so SwiftPM checkouts exist under DerivedData)." >&2
    exit 1
  fi
  echo "PASS [Crashlytics]: flutterfire CLI absent; SPM upload-symbols found at $UPLOAD_SYMBOLS"
else
  echo "PASS [Crashlytics]: flutterfire CLI available"
fi


python3 - "$SOURCE_PLIST" "$PRIVACY_MANIFEST" "$APP_FRAMEWORK_INFO" "$PROJECT_PBXPROJ" "$PUBSPEC" "$GENERATED_PACKAGE" "$EXPECTED_DEPLOYMENT_TARGET" "${1:-}" "$FIX_MODE" "$GENERATED_XCCONFIG" "$LAST_SUBMITTED_BUILD" <<'PY'
import base64
import os
import plistlib
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

args = sys.argv[1:]
source_path = Path(args[0])
privacy_path = Path(args[1])
app_framework_path = Path(args[2])
pbxproj_path = Path(args[3])
pubspec_path = Path(args[4])
generated_package_path = Path(args[5])
expected_deployment_target = args[6]
built_app = Path(args[7]) if len(args) > 7 and args[7] else None
fix_mode = len(args) > 8 and args[8] == "fix"
generated_xcconfig_path = Path(args[9])
last_submitted_build = int(args[10])

ok = True


def fail(message: str):
    global ok
    ok = False
    print(f"FAIL: {message}", file=sys.stderr)


def load_plist(path: Path):
    if not path.exists():
        fail(f"missing plist: {path}")
        return {}
    with path.open("rb") as handle:
        return plistlib.load(handle)


def check_info_plist(path: Path, label: str):
    info = load_plist(path)
    failures = []

    if "NSUserTrackingUsageDescription" in info:
        failures.append(
            "NSUserTrackingUsageDescription is present; remove it because this app does not use ATT/tracking"
        )
    if info.get("ITSAppUsesNonExemptEncryption") is not False:
        failures.append("ITSAppUsesNonExemptEncryption must be false")

    required_usage = {
        # NSLocationAlwaysAndWhenInUseUsageDescription is REQUIRED even though the
        # app only requests when-in-use at runtime: MapLibre/geolocator_apple ship
        # requestAlwaysAuthorization symbols in their binaries, so Apple's ITMS-90683
        # scanner demands the purpose string. Removing it regresses App Store uploads.
        "NSLocationAlwaysAndWhenInUseUsageDescription": "location",
        "NSLocationWhenInUseUsageDescription": "location",
        "NSCameraUsageDescription": "camera",
        "NSPhotoLibraryUsageDescription": "photo library",
    }
    for key, capability in required_usage.items():
        if not isinstance(info.get(key), str) or not info[key].strip():
            failures.append(f"{key} is missing or empty ({capability} access is used)")

    if failures:
        for failure in failures:
            print(f"FAIL [{label}]: {failure}", file=sys.stderr)
        return False

    print(f"PASS [{label}]: no ATT usage key; required permissions and export compliance are present")
    return True


# Deployment target consistency
app_framework = load_plist(app_framework_path)
# Flutter 3.47+ migrates this key out of the file (the target comes from project.pbxproj),
# so a missing key is fine; a present key must match.
if app_framework.get("MinimumOSVersion") not in (None, expected_deployment_target):
    fail(
        f"ios/Flutter/AppFrameworkInfo.plist MinimumOSVersion is "
        f"{app_framework.get('MinimumOSVersion')!r}, expected {expected_deployment_target!r} "
        f"(must match IPHONEOS_DEPLOYMENT_TARGET in project.pbxproj)"
    )
else:
    print(f"PASS [AppFrameworkInfo.plist]: MinimumOSVersion absent or == {expected_deployment_target}")

if pbxproj_path.exists():
    pbxproj_text = pbxproj_path.read_text()
    occurrences = re.findall(r"IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);", pbxproj_text)
    if not occurrences:
        fail(f"IPHONEOS_DEPLOYMENT_TARGET not found in {pbxproj_path}")
    elif any(version != expected_deployment_target for version in occurrences):
        fail(f"inconsistent IPHONEOS_DEPLOYMENT_TARGET in project.pbxproj: {occurrences}")
    elif len(occurrences) < 3:
        fail(f"IPHONEOS_DEPLOYMENT_TARGET only set in {len(occurrences)} of 3 build configs: {occurrences}")
    else:
        print(
            f"PASS [project.pbxproj]: IPHONEOS_DEPLOYMENT_TARGET == "
            f"{expected_deployment_target} in all {len(occurrences)} configs"
        )

# Generated SwiftPM plugin package (FlutterGeneratedPluginSwiftPackage)
if not generated_package_path.exists():
    fail(
        f"generated SwiftPM plugin package not found at {generated_package_path}. "
        f"Run `flutter build ios --config-only` (or `flutter build ios`) first."
    )
else:
    package_text = generated_package_path.read_text()
    if f'.iOS("{expected_deployment_target}")' not in package_text:
        # flutter_tools hardcodes .iOS("13.0") when generating this manifest and only
        # raises it to the project's real deployment target inside `flutter build
        # ios/ipa`. So `flutter pub get` followed by an Xcode build always fails.
        patched, count = re.subn(
            r'\.iOS\("[0-9.]+"\)', f'.iOS("{expected_deployment_target}")', package_text, count=1
        )
        if fix_mode and count == 1:
            generated_package_path.write_text(patched)
            print(
                f"FIXED [FlutterGeneratedPluginSwiftPackage]: platforms -> "
                f".iOS({expected_deployment_target})"
            )
        else:
            fail(
                f"generated SwiftPM plugin package does not declare .iOS(\"{expected_deployment_target}\"). "
                f"This causes 'requires minimum platform version ... but this target supports 13.0' errors. "
                f"Re-run `flutter build ios --config-only` (or this script with --fix) "
                f"after any `flutter pub get`."
            )
    else:
        print(f"PASS [FlutterGeneratedPluginSwiftPackage]: platforms == .iOS({expected_deployment_target})")

# Version / build number drift
pubspec_text = pubspec_path.read_text() if pubspec_path.exists() else ""
version_match = re.search(
    r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)", pubspec_text, re.MULTILINE
)
if version_match:
    marketing_version, build_number = version_match.groups()
    print(f"INFO [pubspec.yaml]: version {marketing_version}+{build_number}")
    if int(build_number) <= last_submitted_build:
        fail(
            f"pubspec build number {build_number} is not greater than LAST_SUBMITTED_BUILD "
            f"({last_submitted_build}); App Store Connect rejects a reused build number"
        )
    else:
        print(f"PASS [pubspec.yaml]: build {build_number} > LAST_SUBMITTED_BUILD {last_submitted_build}")
else:
    fail(f"could not parse version from {pubspec_path}")

ok = check_info_plist(source_path, "source Info.plist") and ok


def check_dart_defines(path: Path):
    """Decode DART_DEFINES from Generated.xcconfig. Never prints define values."""
    if not path.exists():
        fail(f"missing {path}. Run `flutter build ios --config-only --release --dart-define-from-file=...` first.")
        return
    match = re.search(r"^DART_DEFINES=(.*)$", path.read_text(), re.MULTILINE)
    defines = {}
    for entry in (match.group(1).split(",") if match else []):
        try:
            key, _, value = base64.b64decode(entry).decode().partition("=")
        except Exception:
            continue
        defines[key] = value
    if not defines:
        fail(f"no DART_DEFINES in {path}; the build would use no production defines")
        return
    failures = []
    for key in ("DEBUG_MODE", "LOG_API_CALLS", "FIREBASE_APPCHECK_DEBUG"):
        if defines.get(key, "").lower() == "true":
            failures.append(f"{key}=true")
    for key in ("FIREBASE_ENABLED", "FIREBASE_CRASHLYTICS", "FIREBASE_APPCHECK"):
        if defines.get(key, "").lower() == "false":
            failures.append(f"{key}=false")
    api = urlparse(defines.get("API_BASE_URL", ""))
    if api.scheme != "https" or api.hostname != "api.360ghar.com" or api.username or api.password:
        failures.append("API_BASE_URL must be an https URL on host api.360ghar.com")
    for key in ("SUPABASE_URL", "SUPABASE_PUBLISHABLE_KEY"):
        if not defines.get(key, "").strip():
            failures.append(f"{key} is missing or empty")
    if failures:
        for failure in failures:
            fail(f"[DART_DEFINES in Generated.xcconfig] {failure}")
    else:
        print("PASS [DART_DEFINES]: production defines are set (no debug flags, Firebase on, prod API, Supabase present)")


if os.environ.get("VERIFY_SKIP_DART_DEFINES") == "1":
    # CI has no production defines; the owner's build machine runs this check.
    print("SKIP [DART_DEFINES]: VERIFY_SKIP_DART_DEFINES=1")
else:
    check_dart_defines(generated_xcconfig_path)

# Privacy manifest
privacy = load_plist(privacy_path)
if privacy.get("NSPrivacyTracking") is not False:
    fail("PrivacyInfo.xcprivacy NSPrivacyTracking must be false")
else:
    print("PASS [PrivacyInfo.xcprivacy]: NSPrivacyTracking is false")

if built_app:
    built_info = built_app / "Info.plist"
    if not built_info.exists():
        fail(f"built app Info.plist not found at {built_info}")
    else:
        ok = check_info_plist(built_info, f"built app {built_info}") and ok
        built_plist = load_plist(built_info)
        min_version = built_plist.get("MinimumOSVersion")
        if min_version != expected_deployment_target:
            fail(f"built app MinimumOSVersion is {min_version!r}, expected {expected_deployment_target!r}")
        else:
            print(f"PASS [built app]: MinimumOSVersion == {expected_deployment_target}")
        if version_match:
            if built_plist.get("CFBundleShortVersionString") != marketing_version:
                fail(
                    f"built app CFBundleShortVersionString is "
                    f"{built_plist.get('CFBundleShortVersionString')!r}, expected {marketing_version!r} "
                    f"(from pubspec.yaml)"
                )
            if built_plist.get("CFBundleVersion") != build_number:
                fail(
                    f"built app CFBundleVersion is {built_plist.get('CFBundleVersion')!r}, "
                    f"expected {build_number!r} (from pubspec.yaml build number)"
                )
            else:
                print(
                    f"PASS [built app]: CFBundleShortVersionString/CFBundleVersion == "
                    f"{marketing_version}+{build_number}"
                )

if not ok:
    raise SystemExit(1)
PY
