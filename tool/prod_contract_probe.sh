#!/usr/bin/env bash
# Usage: prod_contract_probe.sh [base-url]   (default https://api.360ghar.com)
# Read-only probe: checks that the deployed backend serves the contract this app build expects.
# Sends GET requests and POST /api/v1/versions/check only. Exit 1 if any check FAILs.
set -u

BASE="${1:-https://api.360ghar.com}"
BASE="${BASE%/}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_LINE="$(grep -m1 '^version:' "$ROOT_DIR/pubspec.yaml" | awk '{print $2}')"
VERSION="${VERSION_LINE%%+*}"
BUILD="${VERSION_LINE##*+}"

for tool in curl jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "FAIL: $tool is required" >&2; exit 2; }
done

FAILS=0
BODY="$(mktemp)"
trap 'rm -f "$BODY"' EXIT

pass() { echo "PASS [$1]: $2"; }
fail() { echo "FAIL [$1]: $2"; FAILS=$((FAILS + 1)); }
warn() { echo "WARN [$1]: $2"; }

# request <curl args...>: sets CODE and writes the response body to $BODY
request() {
  CODE="$(curl -sS -m 20 -o "$BODY" -w '%{http_code}' "$@" 2>/dev/null || true)"
  CODE="${CODE:-000}"
}

# rate-limited responses are not a contract answer
throttled() {
  [ "$CODE" = "429" ] && { warn "$1" "HTTP 429 (rate limited), check not evaluated"; return 0; }
  return 1
}

echo "Probing $BASE for app $VERSION+$BUILD"

# (a) versions/check must not offer an update to the build being submitted
NAME="a versions/check"
request -X POST "$BASE/api/v1/versions/check" -H 'Content-Type: application/json' \
  -d "{\"app\":\"ghar\",\"platform\":\"ios\",\"current_version\":\"$VERSION\",\"build_number\":$BUILD}"
if ! throttled "$NAME"; then
  if [ "$CODE" != "200" ]; then
    fail "$NAME" "HTTP $CODE"
  elif [ "$(jq -r '.update_available' "$BODY" 2>/dev/null)" = "false" ]; then
    pass "$NAME" "update_available is false for $VERSION+$BUILD"
  else
    fail "$NAME" "update_available=$(jq -r '.update_available' "$BODY" 2>/dev/null) latest_version=$(jq -r '.latest_version' "$BODY" 2>/dev/null) (old string-compare backend?)"
  fi
fi

# (b) amenities returns an object with an items array
NAME="b amenities"
request "$BASE/api/v1/amenities"
if ! throttled "$NAME"; then
  if [ "$CODE" != "200" ]; then
    fail "$NAME" "HTTP $CODE"
  elif jq -e '(type == "object") and (.items | type == "array")' "$BODY" >/dev/null 2>&1; then
    pass "$NAME" "object with items array ($(jq '.items | length' "$BODY") items)"
  else
    fail "$NAME" "body is not an object with an items array (old bare-list shape?)"
  fi
fi

# (c) the paged assistant messages route exists and requires auth
NAME="c agent messages/page"
request "$BASE/api/v1/agent/conversations/1/messages/page"
if ! throttled "$NAME"; then
  case "$CODE" in
    401) pass "$NAME" "HTTP 401 without auth (route exists)" ;;
    404) fail "$NAME" "HTTP 404 (route missing, old backend)" ;;
    *) fail "$NAME" "HTTP $CODE, expected 401" ;;
  esac
fi

# (d) properties list uses the cursor page envelope
NAME="d properties envelope"
request "$BASE/api/v1/properties?limit=1"
if ! throttled "$NAME"; then
  if [ "$CODE" != "200" ]; then
    fail "$NAME" "HTTP $CODE"
  elif jq -e 'has("items") and has("next_cursor") and has("has_more") and has("limit") and has("total")' "$BODY" >/dev/null 2>&1; then
    pass "$NAME" "keys items, next_cursor, has_more, limit, total present"
  else
    fail "$NAME" "missing keys; got: $(jq -c 'keys' "$BODY" 2>/dev/null || echo 'non-JSON body')"
  fi
fi

# (e) health over the default route
NAME="e health"
request "$BASE/health"
if ! throttled "$NAME"; then
  [ "$CODE" = "200" ] && pass "$NAME" "HTTP 200" || fail "$NAME" "HTTP $CODE"
fi

# (f) health over IPv6 (App Review networks can be IPv6-only)
NAME="f health ipv6"
if [ -z "$(route -n get -inet6 default 2>/dev/null)" ] && [ -z "$(ip -6 route show default 2>/dev/null)" ]; then
  echo "SKIP [$NAME]: no IPv6 default route on this machine"
else
  request -6 "$BASE/health"
  if ! throttled "$NAME"; then
    [ "$CODE" = "200" ] && pass "$NAME" "HTTP 200 over IPv6" || fail "$NAME" "HTTP $CODE over IPv6"
  fi
fi

if [ "$FAILS" -gt 0 ]; then
  echo "RESULT: $FAILS check(s) FAILED"
  exit 1
fi
echo "RESULT: all checks passed"
