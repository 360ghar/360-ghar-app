#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_PLIST="$ROOT_DIR/ios/Runner/Info.plist"
PRIVACY_MANIFEST="$ROOT_DIR/ios/Runner/PrivacyInfo.xcprivacy"
APP_FRAMEWORK_INFO="$ROOT_DIR/ios/Flutter/AppFrameworkInfo.plist"
PROJECT_PBXPROJ="$ROOT_DIR/ios/Runner.xcodeproj/project.pbxproj"
PUBSPEC="$ROOT_DIR/pubspec.yaml"
GENERATED_PACKAGE="$ROOT_DIR/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"

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


python3 - "$SOURCE_PLIST" "$PRIVACY_MANIFEST" "$APP_FRAMEWORK_INFO" "$PROJECT_PBXPROJ" "$PUBSPEC" "$GENERATED_PACKAGE" "$EXPECTED_DEPLOYMENT_TARGET" "${1:-}" <<'PY'
import plistlib
import re
import sys
from pathlib import Path

args = sys.argv[1:]
source_path = Path(args[0])
privacy_path = Path(args[1])
app_framework_path = Path(args[2])
pbxproj_path = Path(args[3])
pubspec_path = Path(args[4])
generated_package_path = Path(args[5])
expected_deployment_target = args[6]
built_app = Path(args[7]) if len(args) > 7 and args[7] else None

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
if app_framework.get("MinimumOSVersion") != expected_deployment_target:
    fail(
        f"ios/Flutter/AppFrameworkInfo.plist MinimumOSVersion is "
        f"{app_framework.get('MinimumOSVersion')!r}, expected {expected_deployment_target!r} "
        f"(must match IPHONEOS_DEPLOYMENT_TARGET in project.pbxproj)"
    )
else:
    print(f"PASS [AppFrameworkInfo.plist]: MinimumOSVersion == {expected_deployment_target}")

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
        fail(
            f"generated SwiftPM plugin package does not declare .iOS(\"{expected_deployment_target}\"). "
            f"This causes 'requires minimum platform version ... but this target supports 13.0' errors. "
            f"Re-run `flutter build ios --config-only` after any `flutter pub get`."
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
else:
    fail(f"could not parse version from {pubspec_path}")

ok = check_info_plist(source_path, "source Info.plist") and ok

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
