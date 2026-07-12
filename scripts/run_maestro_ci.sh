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

DEVICE_ARG=()

build_and_install_ios() {
  if ! command -v xcrun >/dev/null 2>&1; then
    echo "xcrun is required for iOS runs" >&2
    exit 1
  fi

  local device_id
  device_id="$(xcrun simctl list devices booted | grep -m1 -Eo '[A-F0-9-]{8}-[A-F0-9-]{4}-[A-F0-9-]{4}-[A-F0-9-]{4}-[A-F0-9-]{12}' || true)"
  if [[ -z "${device_id}" ]]; then
    echo "No booted iOS simulator found. Boot one and re-run." >&2
    exit 1
  fi

  echo "Using iOS simulator: ${device_id}"
  (cd "${APP_DIR}" && flutter build ios --debug --simulator --no-codesign --dart-define-from-file="${DART_DEFINES_FILE}")
  xcrun simctl install "${device_id}" "${APP_DIR}/build/ios/iphonesimulator/Runner.app"

  DEVICE_ARG=(--device "${device_id}")
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
  (cd "${APP_DIR}" && flutter build apk --debug --dart-define-from-file="${DART_DEFINES_FILE}")
  adb -s "${serial}" install -r "${APP_DIR}/build/app/outputs/flutter-apk/app-debug.apk"

  DEVICE_ARG=(--device "${serial}")
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
maestro test "${FLOW_FILE}" \
  "${DEVICE_ARG[@]}" \
  --format junit \
  --output "${JUNIT_OUT}" \
  -e API_BASE_URL="${API_BASE_URL}"

echo "Maestro run complete. JUnit: ${JUNIT_OUT}"
