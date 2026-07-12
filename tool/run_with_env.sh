#!/usr/bin/env bash
# Run or build Flutter with config from a gitignored .env file via dart-defines.
# Secrets are NOT packaged as Flutter assets.
#
# Usage:
#   ./tool/run_with_env.sh                      # .env.development + flutter run
#   ./tool/run_with_env.sh run -d chrome
#   ./tool/run_with_env.sh .env.production build apk --release

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Default to .env.development when the first arg is a flutter subcommand or absent.
if [[ $# -lt 1 ]]; then
  ENV_FILE=".env.development"
  set -- run
elif [[ "$1" == run || "$1" == build || "$1" == test || "$1" == drive || "$1" == attach ]]; then
  ENV_FILE=".env.development"
else
  ENV_FILE="$1"
  shift
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Env file not found: $ENV_FILE" >&2
  echo "Copy from .env.development.example and fill in values." >&2
  exit 66
fi

# Keep debug map in sync so bare `flutter run` also works in this workspace.
dart run tool/sync_dev_env.dart "$ENV_FILE" >/dev/null || true

DEFINES_FILE="$(mktemp -t ghar360_dart_defines.XXXXXX.json)"
trap 'rm -f "$DEFINES_FILE"' EXIT

dart run tool/env_to_dart_defines.dart "$ENV_FILE" > "$DEFINES_FILE"

FLUTTER_ARGS=("$@")
if [[ ${#FLUTTER_ARGS[@]} -eq 0 ]]; then
  FLUTTER_ARGS=(run)
fi

# Insert dart-define-from-file after the subcommand (run/build/test/...).
SUB="${FLUTTER_ARGS[0]}"
REST=("${FLUTTER_ARGS[@]:1}")
exec flutter "$SUB" --dart-define-from-file="$DEFINES_FILE" "${REST[@]}"
