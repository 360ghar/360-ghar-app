# RCA: "Upload Symbols Failed" — 6 missing dSYMs (Firebase / MapLibre / Recaptcha / GoogleAds)

**Date:** 2026-08-01 · **Applies to:** `1.0.9+15` (and every archive since the project
moved to SwiftPM-only iOS dependencies, ~26 Jul 2026)

## Symptom

After distributing an archive to App Store Connect, the symbol-upload step reported:

> Upload Symbols Failed — The archive did not include a dSYM for the
> FirebaseAnalytics.framework / GoogleAdsOnDeviceConversion.framework /
> GoogleAppMeasurement.framework / GoogleAppMeasurementIdentitySupport.framework /
> MapLibre.framework / RecaptchaEnterpriseSDK.framework with the UUIDs [...] —
> Ensure that the archive's dSYM folder includes a DWARF file with the expected UUIDs.

Verified UUIDs (from `xcrun dwarfdump --uuid` on the binaries inside
`Runner.app/Frameworks/` of the archive):

| Framework | UUID | Delivery mechanism |
|---|---|---|
| FirebaseAnalytics | `8A2843CF-5DF8-3808-B4CB-88ECE263CD3D` | SPM binary artifact (`dl.google.com/.../swiftpm/12.15.0/FirebaseAnalytics.zip`) |
| GoogleAdsOnDeviceConversion | `01B8FE7F-96FA-3B01-B07A-A9BDA1F0E69B` | SPM binary artifact |
| GoogleAppMeasurement | `BC55FE7B-1935-347E-B87E-B0508E854428` | SPM binary artifact |
| GoogleAppMeasurementIdentitySupport | `3598FFA5-839F-3714-A462-79031E6066FA` | SPM binary artifact |
| MapLibre | `30B84B8E-E7BB-358B-9C6C-0E8C908793F6` | SPM binary artifact (`MapLibre.dynamic.xcframework.zip`, v6.27.0) |
| RecaptchaEnterpriseSDK | `0AC2F423-8482-3DD7-9FC1-C705E7C74DAF` | SPM binary artifact |

## Root cause

1. **All six frameworks are prebuilt binary SwiftPM packages.** Their `Package.swift`
   manifests declare `.binaryTarget(...)`, so Xcode downloads prebuilt
   `.xcframework` archives into `DerivedData/.../SourcePackages/artifacts/` and
   **never compiles them** — therefore Xcode can never generate a dSYM for them,
   regardless of `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym` (already set in
   Release — it only affects locally-compiled code).
2. **The vendors ship no dSYM in those archives.** A `find` across
   `SourcePackages/artifacts` + `SourcePackages/checkouts` found zero `*.dSYM`
   (only Crashlytics unit-test fixtures). Google's Firebase 12.x SwiftPM zips,
   MapLibre's iOS release zips, the reCAPTCHA Enterprise SDK and the
   GoogleAdsOnDeviceConversion SDK all omit dSYMs. (Firebase 12 is SPM-first;
   the old CocoaPods tarballs for these pods 404.)
3. **The archive's `dSYMs/` folder therefore only contains what was compiled
   locally:** `Runner.app.dSYM`, `Flutter.framework.dSYM`, `App.framework.dSYM`,
   `objective_c.framework.dSYM`. All statically-linked SwiftPM code (FirebaseCore,
   Crashlytics itself, etc.) is linked into `Runner` and is covered by
   `Runner.app.dSYM` — which is exactly why *only these six dynamic prebuilts*
   are flagged.
4. **Not a regression.** The 27-Jul archive (previous release) has the identical
   dSYM gap; the 26-Jul CocoaPods-era archive still contained third-party dSYMs.

### Secondary issue found during the investigation

The FlutterFire Crashlytics upload build phase invokes
`flutterfire upload-crashlytics-symbols`, but the `flutterfire` CLI is **not
installed** on the build machine. The generated phase script has no `set -e`, so
a missing `flutterfire` produced a silent success — meaning Crashlytics was
receiving **no dSYMs at all** (not even `Runner.app`'s).

## Impact

- **Non-fatal:** the build still uploads and processes in App Store Connect; the
  "Upload Symbols Failed" entries are warnings.
- Crashlytics cannot symbolize stack frames inside those six frameworks (frames
  appear as raw addresses). MapLibre is a meaningful crash surface (map screen).
- The App Store Connect crash view loses the same symbolication.


## Why this cannot be fully "fixed" by configuration

There is no build setting, script, or archive option that can produce a dSYM for
a prebuilt binary that does not contain debug info. The only theoretical paths
(build MapLibre from source, wait for vendors to publish dSYMs) are heavy /
out of our control. The fix therefore makes the pipeline upload **everything
that exists**, reports the residual gaps explicitly, and prevents silent no-ops.

## Fix (implemented)

1. **Harden the Crashlytics Run Script phase** (`ios/Runner.xcodeproj/project.pbxproj`):
   - Resolves the Crashlytics upload script for both SwiftPM layouts (standard
     Xcode DerivedData and Flutter's `build/ios` DerivedData used by
     `flutter build ipa`) and CocoaPods.
   - Prefers `flutterfire` when installed; otherwise invokes the SwiftPM-checkout
     `Crashlytics/run` script directly.
   - `set -euo pipefail` + explicit errors — no more silent no-ops.
   - Skips Debug builds (debug symbols are useless to Crashlytics).
2. **`tool/upload_ios_symbols.sh`** — post-archive collector/uploader:
   - Maps every binary inside the archive's `.app` to its UUIDs, collects dSYMs
     from the archive and all DerivedData build products, uploads the union to
     Crashlytics via `Crashlytics/upload-symbols -gsp ios/Runner/GoogleService-Info.plist -p ios`.
   - Prints a coverage report; the six expected gaps are annotated as such.
   - `--dry-run` supported.
3. **`tool/verify_ios_release.sh`** fails fast when neither `flutterfire` nor the
   SPM `upload-symbols` tool exists.
4. **`RELEASE_IOS.md`** documents the post-archive step and the expected warnings.

## Expected residual warnings

After the fix, re-archiving/uploading will still report "Upload Symbols Failed"
for the six prebuilt frameworks **unless their vendors publish dSYMs**. Treat
these as expected:

- [ ] firebase/firebase-ios-sdk — dSYMs for SwiftPM binary artifacts (Analytics / AppMeasurement)
- [ ] maplibre/maplibre-gl-native — dSYM in iOS release distribution
- [ ] GoogleCloudPlatform/recaptcha-enterprise-mobile-sdk — dSYM in release zip
- [ ] googleads/google-ads-on-device-conversion-ios-sdk — dSYM in release zip

## How to verify the fix works

```bash
# 1. After archiving (Xcode Organizer or flutter build ipa):
./tool/upload_ios_symbols.sh            # uploads every available dSYM to Crashlytics
./tool/upload_ios_symbols.sh --dry-run  # coverage report only

# 2. Pre-build guard:
./tool/verify_ios_release.sh
```

The Crashlytics dashboard should show dSYMs for `Runner`, `Flutter`, `App` and
`objective_c` (check Debug → Crashlytics → dSYMs or the "Missing dSYMs" banner).
