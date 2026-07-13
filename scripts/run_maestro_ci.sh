#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLATFORM="${1:-ios}"
SUITE="${2:-full}"
FLOW_FILE="${APP_DIR}/.maestro/${SUITE}.yaml"

# Ensure default Maestro install location is discoverable in non-interactive shells.
if [[ -d "${HOME}/.maestro/bin" ]]; then
  export PATH="${HOME}/.maestro/bin:${PATH}"
fi

if [[ ! -f "${FLOW_FILE}" ]]; then
  echo "Flow file not found: ${FLOW_FILE}" >&2
  exit 1
fi

if [[ -z "${API_BASE_URL:-}" ]]; then
  if [[ -f "${APP_DIR}/.env.development" ]]; then
    API_BASE_URL="$(grep -E '^API_BASE_URL=' "${APP_DIR}/.env.development" | tail -n1 | cut -d'=' -f2- | tr -d '"')"
  elif [[ -f "${APP_DIR}/dart_defines.json" ]]; then
    API_BASE_URL="$(python3 -c "import json; print(json.load(open('${APP_DIR}/dart_defines.json')).get('API_BASE_URL',''))")"
  fi
fi

if [[ -z "${API_BASE_URL:-}" ]]; then
  echo "API_BASE_URL is required (set env var, .env.development, or dart_defines.json)" >&2
  exit 1
fi

# Compile-time config for the app binary (not Flutter assets).
DART_DEFINES_FILE="${APP_DIR}/dart_defines.json"
if [[ ! -f "${DART_DEFINES_FILE}" ]]; then
  if [[ -f "${APP_DIR}/.env.development" ]]; then
    (cd "${APP_DIR}" && dart run tool/env_to_dart_defines.dart .env.development > dart_defines.json)
  else
    echo "dart_defines.json is required for builds (or provide .env.development to generate it)" >&2
    exit 1
  fi
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is required in PATH" >&2
  exit 1
fi

if ! command -v maestro >/dev/null 2>&1; then
  echo "maestro not found. Install via: curl -Ls \"https://get.maestro.mobile.dev\" | bash" >&2
  exit 1
fi

OUTPUT_DIR="${MAESTRO_OUTPUT_DIR:-${APP_DIR}/build/maestro/${SUITE}-${PLATFORM}}"
mkdir -p "${OUTPUT_DIR}"
JUNIT_OUT="${OUTPUT_DIR}/junit.xml"

# Maestro 1.39+: --device is a global flag (before subcommand), not a `test` option.
DEVICE_ID=""

ensure_ios_google_service_plist() {
  local plist="${APP_DIR}/ios/Runner/GoogleService-Info.plist"

  if [[ -n "${IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64:-}" ]]; then
    printf '%s' "${IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64}" | base64 --decode > "${plist}"
    echo "Wrote GoogleService-Info.plist from IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64"
    return 0
  fi

  if [[ -f "${plist}" ]]; then
    return 0
  fi

  # Minimal stub so CI can compile when secrets are unavailable (Firebase features
  # won't work, but the app binary still builds for Maestro UI flows).
  cat > "${plist}" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>ci-dummy-api-key</string>
	<key>GCM_SENDER_ID</key>
	<string>000000000000</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
	<key>BUNDLE_ID</key>
	<string>com.the360ghar.ghar360</string>
	<key>PROJECT_ID</key>
	<string>ghar-ci-dummy</string>
	<key>STORAGE_BUCKET</key>
	<string>ghar-ci-dummy.appspot.com</string>
	<key>IS_ADS_ENABLED</key>
	<false></false>
	<key>IS_ANALYTICS_ENABLED</key>
	<false></false>
	<key>IS_APPINVITE_ENABLED</key>
	<false></false>
	<key>IS_GCM_ENABLED</key>
	<true></true>
	<key>IS_SIGNIN_ENABLED</key>
	<false></false>
	<key>GOOGLE_APP_ID</key>
	<string>1:000000000000:ios:0000000000000000000000</string>
</dict>
</plist>
PLIST
  echo "Wrote stub GoogleService-Info.plist for CI build"
}

build_and_install_ios() {
  if ! command -v xcrun >/dev/null 2>&1; then
    echo "xcrun is required for iOS runs" >&2
    exit 1
  fi

  local device_id
  device_id="$(xcrun simctl list devices booted | grep -m1 -Eo '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' || true)"
  if [[ -z "${device_id}" ]]; then
    echo "No booted iOS simulator found. Boot one and re-run." >&2
    exit 1
  fi

  echo "Using iOS simulator: ${device_id}"
  ensure_ios_google_service_plist
  (cd "${APP_DIR}" && flutter build ios --debug --simulator --no-codesign --dart-define-from-file="${DART_DEFINES_FILE}")
  xcrun simctl install "${device_id}" "${APP_DIR}/build/ios/iphonesimulator/Runner.app"

  DEVICE_ID="${device_id}"
}

build_and_install_android() {
  if ! command -v adb >/dev/null 2>&1; then
    echo "adb is required for Android runs" >&2
    exit 1
  fi

  local serial
  serial="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  if [[ -z "${serial}" ]]; then
    echo "No connected Android emulator/device found." >&2
    exit 1
  fi

  echo "Using Android device: ${serial}"
  export ANDROID_SERIAL="${serial}"
  (cd "${APP_DIR}" && flutter build apk --debug --dart-define-from-file="${DART_DEFINES_FILE}")
  adb -s "${serial}" install -r "${APP_DIR}/build/app/outputs/flutter-apk/app-debug.apk"

  DEVICE_ID="${serial}"
}

case "${PLATFORM}" in
  ios)
    build_and_install_ios
    ;;
  android)
    build_and_install_android
    ;;
  *)
    echo "Unsupported platform: ${PLATFORM}. Use ios|android" >&2
    exit 1
    ;;
esac

cd "${APP_DIR}"

echo "Running Maestro suite: ${FLOW_FILE}"
# Global options must precede the subcommand (Maestro 1.39+ rejects `test --device`).
maestro --device "${DEVICE_ID}" test "${FLOW_FILE}" \
  --format junit \
  --output "${JUNIT_OUT}" \
  -e API_BASE_URL="${API_BASE_URL}"

echo "Maestro run complete. JUnit: ${JUNIT_OUT}"
