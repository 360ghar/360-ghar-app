# Shorebird Code Push — 360 Ghar

Shorebird provides over-the-air (OTA) updates for Flutter release builds. This
doc covers how 360 Ghar uses it for **Android and iOS**, how to release and
patch, and what CI does.

## Overview

- Config lives in [`shorebird.yaml`](../shorebird.yaml) at the repo root
  (`app_id: aed0a9f9-699e-43b0-9da9-6ecab6db57b4`). The `app_id` is **not a
  secret** — it is bundled as a Flutter asset (see `pubspec.yaml`) so the
  in-app updater can find patches.
- `auto_update` is enabled (default): the app checks for patches in the
  background at launch and applies them on the next restart. No Dart code
  changes were needed.
- Shorebird only ships in **release** builds. Debug/profile builds use the
  stock Flutter engine.
- App: [Shorebird Console](https://console.shorebird.dev/apps/aed0a9f9-699e-43b0-9da9-6ecab6db57b4)
> Build 1.1.0+18 ships as a plain flutter build ipa; Shorebird patches cannot target it.

- Releases: `1.0.9+16` registered for `android` and `ios` (Flutter 3.44.8).

## Prerequisites (local machine)

```bash
shorebird --version   # CLI installed (see https://docs.shorebird.dev/getting-started)
shorebird account whoami   # logged in as 360ghar@gmail.com
```

The local Flutter version must match the version used for releases (currently
**3.44.8**; CI pins `--flutter-version 3.44.8`). Patches must be built with the
same Flutter version as the release they target.

## Creating a release

A release is a **store binary built with Shorebird** (it embeds the updater).
Store upload stays manual (Play Console / Transporter), exactly as before.

1. **Bump the version** in `pubspec.yaml` (e.g. `1.0.9+16` → `1.0.10+17`).
   Shorebird refuses to register a version that already exists, and the stores
   reject duplicate build numbers.
2. Build with production config (same keys CI injects):

```bash
dart run tool/env_to_dart_defines.dart .env.production > /tmp/ghar360_defines.json

# Android: produces build/app/outputs/bundle/release/app-release.aab
shorebird release android --dart-define-from-file=/tmp/ghar360_defines.json

# iOS: produces build/ios/ipa/*.ipa
shorebird release ios \
  --dart-define-from-file=/tmp/ghar360_defines.json \
  --export-options-plist=ios/ExportOptions.plist

rm -f /tmp/ghar360_defines.json
```

> The `--export-options-plist=ios/ExportOptions.plist` flag is **required on
> iOS**: without it the export cannot resolve the App Store provisioning
> profile for the app's entitlements (Associated Domains, Push Notifications,
> Sign In with Apple).

3. Verify: `shorebird releases list`.
4. Upload the produced AAB / IPA to the stores using the existing process
   (see `docs/app-store-release-checklist.md`).

> **Critical**: the next store release must be the Shorebird-built binary.
> Users of the current store build (`1.0.9+16`, built without Shorebird) can
> never receive patches. Code push becomes effective for users who install a
> Shorebird-built release.

## Creating a patch

```bash
# Android
shorebird patch android --release-version 1.0.10+17

# iOS
shorebird patch ios --release-version 1.0.10+17
```

Or both at once: `shorebird patch --platforms=android,ios`.

Patches are diffed against the **release** binary (not the previous patch) and
roll out on the `stable` channel. Use `--track staging` to test a patch with a
staging build first, then promote it.

### Patch limitations

- **Native code** (Kotlin/Swift, plugins with native code that were not in the
  release) cannot be patched — that requires a new store release.
- **iOS**: changed/added Dart code runs in a Dart interpreter (slightly slower
  than AOT; noticeable for hot loops like image processing). Patches do not
  work on the iOS Simulator — test on a physical device.
- Pure-Dart package changes (including new pure-Dart deps) are patchable.

## CI

> Note: `shorebird release --dry-run` cannot be used for CI validation on a
> released version — Shorebird rejects it with "existing release for version
> X" (verified against 1.6.115). Releases are therefore triggered manually via
> `workflow_dispatch` after bumping the version, and push/PR CI stays on the
> plain Flutter build.

### Android (`.github/workflows/build.yml`)

- Push/PR builds are unchanged: plain `flutter build apk` (no Shorebird
  dependency, always green).
- **Manual dispatch** (`workflow_dispatch`) registers a Shorebird release:
  decodes the release keystore into `android/key.properties`, runs
  `shorebird release android --artifact apk` (produces AAB + APK), and uploads
  both as artifacts. Dispatch fails fast with clear messages if
  `SHOREBIRD_TOKEN` or the keystore secrets are missing. Only dispatch after
  bumping `pubspec.yaml` — the version must not already exist on Shorebird.

### iOS (`.github/workflows/release-ios.yml`)

- `workflow_dispatch` only, on `macos-15`. Registers the release and uploads
  the signed IPA as an artifact for manual App Store Connect upload
  (Transporter / altool). Same "bump the version first" rule as Android.
- Signing: the workflow pins Xcode (latest-stable), imports the distribution
  cert into a temporary keychain, installs the profile named by its **UUID**
  under `~/Library/MobileDevice/Provisioning Profiles`, and generates a
  manual-signing `ExportOptions.plist` from that UUID. The repo's
  `ios/ExportOptions.plist` (automatic signing) is used for local builds.

### Required GitHub secrets

| Secret | Used by | How to get it |
| --- | --- | --- |
| `SHOREBIRD_TOKEN` | both workflows | Shorebird Console → **Account → API Keys** → Create API Key (write scope). `shorebird login:ci` is removed in current CLIs. |
| `ANDROID_KEYSTORE_BASE64` | build.yml | Release keystore (`.jks`) as base64: `base64 -i release.jks` |
| `ANDROID_KEYSTORE_ALIAS` | build.yml | `keyAlias` from your local `android/key.properties` |
| `ANDROID_KEYSTORE_PASSWORD` | build.yml | Keystore password (used for both key and store, same as your local `key.properties`); the workflow writes `android/key.properties` from these secrets |
| `IOS_DISTRIBUTION_CERT_P12_BASE64` | iOS workflow | Export the **Apple Distribution** certificate from Keychain Access as `.p12`, `base64 -i dist.p12` |
| `IOS_DISTRIBUTION_CERT_PASSWORD` | iOS workflow | Password of the `.p12` above |
| `IOS_PROVISION_PROFILE_BASE64` | iOS workflow | App Store provisioning profile for `com.the360ghar.ghar360` (with Associated Domains, Push Notifications, Sign In with Apple), `base64 -i profile.mobileprovision` |

## Version policy

- Every **store release**: bump `pubspec.yaml` version, `shorebird release`
  for both platforms, upload to stores.
- In between: use `shorebird patch` for hotfixes.
- If you upgrade Flutter, upgrade the pinned `--flutter-version` in both
  workflows and re-run `shorebird release` for the new store build (patches
  cannot cross Flutter versions).

## Notes

- Free plan ("Hobby") is single-developer; patch installs count toward plan
  usage (see Shorebird billing docs).
- The updater is store-policy compliant on both stores (Android: VM/interpreter
  exemption; iOS: 3.3.1b interpreter rule). Don't use patches to change the
  app's primary purpose.
- `in_app_update` (Play Store updates) and Shorebird patches are independent
  and coexist.
- **Building iOS in Xcode after a `flutter pub get`?** Run
  `./tool/verify_ios_release.sh --fix` first. `pub get` regenerates the SwiftPM
  plugin manifest with a hardcoded `.iOS("13.0")` while Firebase requires 15.0,
  so Xcode fails with *"requires minimum platform version 15.0 ... but this
  target supports 13.0"*. `shorebird release ios` and `flutter build ios/ipa`
  repair the manifest themselves, so CI is unaffected — this only bites
  Xcode-driven builds and archives.
