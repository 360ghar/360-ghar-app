#!/usr/bin/env bash
#
# Netlify build script for the ghar360 Flutter web app.
#
# Netlify's build image has no Flutter SDK, so we install a pinned version,
# inject config via --dart-define-from-file (not Flutter assets), then build the
# release web bundle into build/web (the publish dir in netlify.toml).
#
# Configure secrets in: Netlify dashboard -> Site configuration ->
# Environment variables (scoped to Production and Deploy previews).

set -euo pipefail

# Keep this in sync with .fvmrc and .github/workflows/build.yml.
FLUTTER_VERSION="3.44.6"

# Cache the SDK between builds when Netlify exposes a persistent cache dir.
CACHE_DIR="${NETLIFY_BUILD_BASE:-$HOME}/cache"
FLUTTER_DIR="${CACHE_DIR}/flutter"

# ---------------------------------------------------------------------------
# 1. Install Flutter (pinned). Reuse the cached SDK if it is the right version.
# ---------------------------------------------------------------------------
mkdir -p "${CACHE_DIR}"

needs_install=true
if [ -x "${FLUTTER_DIR}/bin/flutter" ]; then
  cached_version="$("${FLUTTER_DIR}/bin/flutter" --version 2>/dev/null | head -n1 || true)"
  if echo "${cached_version}" | grep -q "${FLUTTER_VERSION}"; then
    echo "Using cached Flutter ${FLUTTER_VERSION}"
    needs_install=false
  else
    echo "Cached Flutter is stale (${cached_version}); reinstalling"
    rm -rf "${FLUTTER_DIR}"
  fi
fi

if [ "${needs_install}" = true ]; then
  echo "Downloading Flutter ${FLUTTER_VERSION}..."
  TARBALL="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${TARBALL}"
  curl -fsSL --retry 3 -o "${CACHE_DIR}/${TARBALL}" "${URL}"
  tar -xf "${CACHE_DIR}/${TARBALL}" -C "${CACHE_DIR}"
  rm -f "${CACHE_DIR}/${TARBALL}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"

# Mark the SDK dir safe for git (Flutter runs git internally).
git config --global --add safe.directory "${FLUTTER_DIR}" || true

flutter --version
flutter config --enable-web
flutter precache --web

# ---------------------------------------------------------------------------
# 2. Generate compile-time dart-defines from Netlify environment variables.
#    Secrets are NOT written as Flutter assets (extractable from the bundle).
#    Do NOT print the file contents — avoid leaking secrets into logs.
# ---------------------------------------------------------------------------
: "${SUPABASE_URL:?SUPABASE_URL is required (set it in Netlify env vars)}"
: "${SUPABASE_PUBLISHABLE_KEY:?SUPABASE_PUBLISHABLE_KEY is required (set it in Netlify env vars)}"

python3 - <<'PY'
import json, os
def env(key, default=""):
    v = os.environ.get(key)
    return default if v is None or v == "" else v
payload = {
    "SUPABASE_URL": env("SUPABASE_URL"),
    "SUPABASE_PUBLISHABLE_KEY": env("SUPABASE_PUBLISHABLE_KEY"),
    "API_BASE_URL": env("API_BASE_URL", "https://api.360ghar.com"),
    "GOOGLE_PLACES_API_KEY": env("GOOGLE_PLACES_API_KEY"),
    "GOOGLE_WEB_CLIENT_ID": env("GOOGLE_WEB_CLIENT_ID"),
    "GOOGLE_IOS_CLIENT_ID": env("GOOGLE_IOS_CLIENT_ID"),
    "DEFAULT_COUNTRY": env("DEFAULT_COUNTRY", "in"),
    "DEBUG_MODE": env("DEBUG_MODE", "false"),
    "LOG_API_CALLS": env("LOG_API_CALLS", "false"),
    "FIREBASE_ENABLED": env("FIREBASE_ENABLED", "false"),
    "FIREBASE_CRASHLYTICS": env("FIREBASE_CRASHLYTICS", "false"),
    "FIREBASE_ANALYTICS": env("FIREBASE_ANALYTICS", "false"),
    "FIREBASE_PERFORMANCE": env("FIREBASE_PERFORMANCE", "false"),
    "FIREBASE_IAM": env("FIREBASE_IAM", "false"),
    "RECAPTCHA_V3_SITE_KEY": env("RECAPTCHA_V3_SITE_KEY"),
}
with open("dart_defines.json", "w", encoding="utf-8") as f:
    json.dump(payload, f)
print("Wrote dart_defines.json (values not printed)")
PY

# ---------------------------------------------------------------------------
# 3. Build the release web bundle. Generated *.g.dart files are committed,
#    so build_runner is not needed.
# ---------------------------------------------------------------------------
flutter pub get
flutter build web --release --base-href=/ --dart-define-from-file=dart_defines.json

echo "Web build complete: build/web"
