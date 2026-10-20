# Maestro Flows (360Ghar)

Use a non-production app configuration and dedicated test accounts for signed-in
flows. Supply `TEST_PHONE` (a verified phone or email), `TEST_PASSWORD`, and, for the
full suite, `TEST_NEW_IDENTIFIER` (an unregistered test identifier). Pass these as
Maestro `-e` parameters; do not put credentials in YAML or commit them.

The onboarding and identifier-validation flows require no account. The signed-in
flows can save a selected browse purpose if profile completion appears. The shared
login flow defers optional personal details, displays the purpose choices, selects
Buy, then saves it before entering the dashboard. It never bypasses mandatory
password setup. The fixture must already have a password and a verified identifier.

Recovery validation clears the identifier prefilled by Login before submitting,
so that validation step does not request an OTP. Signup validation stops at the
required-name error and uses the supplied unregistered fixture. Do not run the full
suite against production data.

## Structure

- Shared subflows: `.maestro/_shared/`
- Route/journey flows: `.maestro/auth`, `.maestro/dashboard`, `.maestro/discover`, `.maestro/explore`, `.maestro/likes`, `.maestro/visits`, `.maestro/profile`, `.maestro/tools`, `.maestro/deeplink`
- Entrypoints:
  - `.maestro/smoke.yaml`
  - `.maestro/full.yaml`

## Run on an explicit device

The runner builds and installs the app on the selected device. Set
`MAESTRO_DEVICE_ID` to a booted iOS simulator UDID or a connected Android serial.
The runner validates this target before building or installing. If the variable is
unset, exactly one available device must exist; zero or multiple devices stop the
run. Offline and unauthorized Android devices are not candidates.

```bash
MAESTRO_DEVICE_ID="<booted-simulator-UDID>" ./scripts/run_maestro_smoke.sh ios
MAESTRO_DEVICE_ID="<booted-simulator-UDID>" ./scripts/run_maestro_full.sh ios
MAESTRO_DEVICE_ID="<connected-Android-serial>" ./scripts/run_maestro_smoke.sh android
```

`MAESTRO_BIN` selects a CLI executable, including an isolated installation. It
defaults to `maestro`. With Maestro 2.6.0 or newer, set a distinct, unused
`MAESTRO_DRIVER_HOST_PORT` for each concurrent run. The runner checks the CLI
version when a port is supplied and puts both device and port before the `test`
subcommand. An unset port preserves the CLI default.

For an isolated CLI and driver, use a dedicated Java user-home directory as well:

```bash
MAESTRO_DEVICE_ID="<booted-simulator-UDID>" \
MAESTRO_BIN="/path/to/isolated/maestro/bin/maestro" \
MAESTRO_DRIVER_HOST_PORT=17017 \
MAESTRO_OPTS="-Duser.home=/tmp/360ghar-maestro-state" \
MAESTRO_CLI_NO_ANALYTICS=1 \
MAESTRO_DISABLE_UPDATE_CHECK=true \
./scripts/run_maestro_ci.sh ios smoke
```

Use a CLI binary without a wrapper that adds another device or driver port. The
runner forwards `TEST_PHONE`, `TEST_PASSWORD`, and `TEST_NEW_IDENTIFIER` only when
supplied in the environment. It does not print their values. `API_BASE_URL` must
match the non-production endpoint compiled into `dart_defines.json`.

## Loopback native fixture flow

`native_fixture_smoke.yaml` checks signed-in native navigation and rendering with
`tool/verification/native_fixture_server.py`. This server binds only to
`127.0.0.1:54321`; fixture changes stay in process memory. It does not validate
production authentication, OTP delivery, or backend contracts.

1. Prepare an isolated debug app copy with synthetic configuration. In its
   `dart_defines.json`, set `API_BASE_URL` and `SUPABASE_URL` to
   `http://127.0.0.1:54321`, `SUPABASE_PUBLISHABLE_KEY` to
   `visual-check-no-credentials`, and `FIREBASE_ENABLED` to `false`. Use an empty
   generated development configuration and a synthetic Firebase plist. Do not
   copy production configuration or credentials.
2. From that copy, start `python3 tool/verification/native_fixture_server.py` in a
   separate terminal. Keep it running during the flow.
3. From the same copy, run the flow on the explicit iOS simulator. Use the isolated
   CLI and driver settings above if another Maestro session is active:

```bash
MAESTRO_DEVICE_ID="<booted-simulator-UDID>" \
MAESTRO_BIN="/path/to/isolated/maestro/bin/maestro" \
MAESTRO_DRIVER_HOST_PORT=17017 \
MAESTRO_OPTS="-Duser.home=/tmp/360ghar-maestro-state" \
API_BASE_URL="http://127.0.0.1:54321" \
TEST_PHONE="fixture@example.invalid" \
TEST_PASSWORD="Fixture123!" \
./scripts/run_maestro_ci.sh ios native_fixture_smoke
```

These are public, synthetic fixture values. The loopback flow currently targets
the iOS simulator; Android requires explicit host-port routing before it can use
the same host-only fixture server. The runner writes JUnit results under
`build/maestro/<suite>-<platform>/` unless `MAESTRO_OUTPUT_DIR` is supplied.

For the local refresh-failure check, leave the app on Preferences after the smoke
flow. Stop only the loopback fixture server, then run
`.maestro/native_fixture_refresh_failure.yaml` with the same CLI, explicit device,
and driver port. It verifies that Saved keeps the loaded property while showing
an error and retry control. Restart the loopback server, then run
`.maestro/native_fixture_refresh_recovery.yaml`; it verifies that retry clears the
error and retains the property. Run these flows in that order without resetting
or relaunching the app. These steps apply only to the isolated loopback app and
must not be used against production.
