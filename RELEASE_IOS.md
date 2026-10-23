# ghar360 - iOS App Store Submission Guide

End-to-end checklist for shipping **ghar360** (`1.1.0+18`, bundle `com.the360ghar.ghar360`, iOS 15.0+, team `HMWGCVU4SV`) to the App Store. Work top-to-bottom. Items marked **[external]** must be done outside this repo (browser / console / backend).

> Companion: `docs/app-store-release-checklist.md`. Build 1.1.0+18 is a plain `flutter build ipa` (no Shorebird). The owner builds, uploads and submits.

---

## 0. Status of code-level readiness (done in this workstream)

- ✅ Account-deletion works end-to-end on the client (`DELETE /api/v1/users/me`; type-`DELETE` confirm dialog; reactive loading; errors via `ErrorHandler`). **Depends on the backend endpoint, see §1.2.**
- ✅ Responsive foundation + 9 screens adapted for iPad (rail-free; bottom-nav kept by choice; content centered/capped; responsive grids; two-pane Property Details & Explore).
- ✅ Info.plist, entitlements, app icon, launch screen, deployment target - all verified (`plutil -lint` clean).
- ✅ Google sign-in is enabled on iOS. `ios/Runner/Info.plist` carries the reversed iOS client ID as a URL scheme, and `GOOGLE_IOS_CLIENT_ID` and `GOOGLE_WEB_CLIENT_ID` come from `.env.production`. See §1.1.
- ⚠️ Pre-existing repo issues that do NOT block submission but should be cleaned: `lib/core/utils/feature_flags.dart` orphan compile error (not imported - won't break the build) and ~105 errors in `test/` (broken scaffolding; not compiled into release).

---

## 1. External pre-flight (do these in parallel with the build)

### 1.1 Google Sign-In on iOS **[external check]**
The app uses the native ID-token flow (`google_sign_in`). Check these before the build:
1. The iOS OAuth client in Google Cloud has bundle ID `com.the360ghar.ghar360`.
2. `GOOGLE_IOS_CLIENT_ID` and `GOOGLE_WEB_CLIENT_ID` are set in `.env.production`.
3. The URL scheme `com.googleusercontent.apps.<id>` in `ios/Runner/Info.plist` is the reversed form of `GOOGLE_IOS_CLIENT_ID`.

### 1.2 Account-deletion backend endpoint **[external, backend team]**
The app calls `DELETE /api/v1/users/me` (authenticated, bearer session token; `AuthRepository.deleteAccount`). The backend hard-deletes the Supabase Auth user, which revokes all sessions, and anonymizes and soft-deletes the local record. The account is unusable after deletion (Apple checks this). The old `POST /api/v1/auth/delete-account` route still exists but the app does not call it. Confirm `DELETE /api/v1/users/me` exists on the deployed backend: `curl -s https://api.360ghar.com/api/v1/openapi.json | jq '.paths["/api/v1/users/me"] | keys'`.

### 1.3 Universal Links - host the AASA file **[external - web/infra]**
The app declares `applinks:` for `360ghar.com` and `www.360ghar.com`, plus `webcredentials:360ghar.com`. Each domain must serve a valid **apple-app-site-association** JSON at:
- `https://<domain>/.well-known/apple-app-site-association` **and** `https://<domain>/apple-app-site-association`
containing team ID `HMWGCVU4SV`, bundle id `com.the360ghar.ghar360`, under `applinks` and `webcredentials`. If missing, universal links silently fail (property deep links won't open the app).

### 1.4 Restrict the Google Places API key **[external - security]**
`GOOGLE_PLACES_API_KEY` is bundled in the client. In Google Cloud Console → **APIs & Services → Credentials**, restrict that key to **iOS** with bundle ID `com.the360ghar.ghar360` (and Android with your Android package) so it can't be abused. (Supabase anon key is public-by-design - just confirm **RLS policies** are enabled on all tables.)

### 1.5 ✅ No App Tracking Transparency / IDFA - RESOLVED
The app does **NOT** use App Tracking Transparency or collect the IDFA. Firebase Analytics is disabled by default and does not require ATT. Therefore:
- `NSUserTrackingUsageDescription` must **NOT** be present in `Info.plist` - its presence caused an App Store submission rejection because it contradicted the "no tracking" App Privacy declaration.
- No ATT prompt is shown at runtime, and the App Privacy label must **not** declare "Advertising ID / Used for Tracking".
- `PrivacyInfo.xcprivacy` declares `NSPrivacyTracking = false` with empty tracking domains - keep it that way. Crashlytics and Performance are NOT tracking.
- If App Store Connect still reports `NSUserTrackingUsageDescription`, the selected build is stale. Do not change the App Privacy answer to tracking; run `./tool/verify_ios_release.sh`, rebuild from the current branch with a new build number, and upload that new archive.

---

## 2. App Store Connect - app metadata **[external]**

Create the app record (My Apps → + → New App, iOS, bundle `com.the360ghar.ghar360`, SKU, primary language English).

- **Name**: `360 Ghar` (or the final brand name; must be unique). **Subtitle** (30 chars): e.g. `Swipe, tour & find your home`.
- **Description** + **Keywords** (100 chars, comma-separated) + **Promotional text**.
- **Support URL** + **Marketing URL** (must be live HTTPS pages - can be `360ghar.com` pages).
- **Privacy Policy URL** (required): the app loads it from `api.360ghar.com/pages/privacy-policy/public`; App Store Connect still needs a **public web URL** - host the same content at e.g. `https://360ghar.com/privacy-policy`.
- **Category**: Primary `Lifestyle` (or `Real Estate` if available), Secondary optional.
- **Age rating**: answer the questionnaire - unrestricted web access = No (the WebView only opens 360° tour URLs, not general browsing), no UGC/gambling/violence → **4+**.
- **Copyright**: `© <year> 360ghar` (or your entity).
- **Price**: Free (no IAP).

## 3. App Privacy "nutrition label" **[external]**

Declare, per data type, whether it is **Collected** and the purposes. Based on the audit:

| Category | Data type | Collected? | Purpose | Linked to user? |
|---|---|---|---|---|
| Contact Info | Phone Number | Yes | Authentication | Yes |
| Contact Info | Email Address | Yes (email OTP/password flows exist) | Authentication | Yes |
| Contact Info | Name | Yes | App Functionality / Personalization | Yes |
| Contact Info | Profile photo | Yes (Cloudinary) | App Functionality | Yes |
| Location | Precise Location | Yes (geolocator, When-in-Use) | App Functionality (nearby properties) | Yes |
| User Content | Photos or Videos | Yes (property uploads) | App Functionality | Yes |
| Identifiers | Device ID | Yes (push token / package_info) | Analytics / Other | Yes |
| Usage Data | Product Interaction | Yes (Firebase Analytics) | Analytics | Yes |
| Diagnostics | Crash / Performance | Yes (Crashlytics, Performance) | App Functionality | Yes |
| Identifiers | Advertising ID | **No - not collected (no ATT, see §1.5)** | - | - |

**Third-party SDKs** ( disclose in the SDK section): Supabase, Firebase (Analytics/Crashlytics/Messaging/Remote Config/Performance), MapLibre, Cloudinary (via backend), Google Places/Sign-In.

**Account deletion**: answer **Yes** to "account deletion" (the app offers it - see §1.2). **Data retention**: state your policy.

## 4. Screenshots **[external]**

Required device sizes (App Store Connect). Capture from simulators at full resolution (File → Save Screen), or fastlane `snapshot`.
- **6.7"** (iPhone 15 Pro Max) - required.
- **6.5"** or **6.1"** (iPhone 14 Plus / 15) - required set.
- **iPad 12.9"** (6th gen) - **required** because the app supports iPad.
- Optional: **5.5"**, and a **30-sec app preview video** per size.
Recommended shots: Discover swipe deck, Explore map, Property details + 360° tour, Likes, Visits, Profile. For iPad, show the two-pane Property Details and the map side-panel to demonstrate tablet polish.

## 5. App Review Information **[external]**

- **Demo credentials**: provide a dedicated review account with **email + password**. The reviewer reaches it through the email sign-in path (`signInWithPassword(email)`, `AuthRepository.signInWithEmailPassword`). Create the account in production before you submit and test the login on the final build.
- **Notes**: describe the core flow - "Browse properties by swiping (Discover), view the map (Explore), open a property to see the 360° virtual tour (WebView), save (Likes), and request a visit (Visits). Account can be deleted from Profile → Privacy → Delete Account."
- **Contact**: name, email, phone.

## 6. Build & upload **[you, on a Mac with Xcode 27.1]**

Build 1.1.0+18 is a plain `flutter build ipa`. Do not use Shorebird for this build.

```bash
# 1. Convert the production env file to dart-defines (the JSON is gitignored)
dart run tool/env_to_dart_defines.dart .env.production > .dart_defines.prod.json

# 2. Resolve deps (iOS plugins use Swift Package Manager; no CocoaPods)
flutter clean && flutter pub get

# 3. Regenerate ios/Flutter/Generated.xcconfig with the production defines.
#    This also resets the generated SwiftPM plugin package to iOS 13.0 (a Flutter default).
flutter build ios --config-only --release --dart-define-from-file=.dart_defines.prod.json

# 4. Check source settings and the defines baked into Generated.xcconfig. --fix repairs the
#    SwiftPM minimum platform (Firebase needs 15.0).
./tool/verify_ios_release.sh --fix

# 5. Check that the production backend serves the new contract (must print no FAIL)
./tool/prod_contract_probe.sh

# 6. Build the IPA
flutter build ipa --release --dart-define-from-file=.dart_defines.prod.json --export-options-plist=ios/ExportOptions.plist

# 7. Verify the built app bundle
./tool/verify_ios_release.sh build/ios/iphoneos/Runner.app
```

8. Upload `build/ios/ipa/*.ipa` with Transporter.

Notes:
- `tool/verify_ios_release.sh` fails when `DEBUG_MODE` or `LOG_API_CALLS` is true, Firebase, Crashlytics or App Check is off, `API_BASE_URL` is not `https://api.360ghar.com`, the Supabase values are empty, or the pubspec build number is not greater than `LAST_SUBMITTED_BUILD` in the script. Raise that constant after each upload.
- Step 5 must pass before you submit. An old backend returns a false "update available" answer, and the app would show an update dialog on launch (the 2.1 rejection).
- Crashlytics symbols: `./tool/upload_ios_symbols.sh` uploads every available dSYM (`--dry-run` prints the coverage report). Expect no "Upload Symbols Failed" warnings. See `docs/dSYM_UPLOAD_RCA.md`.
- `.github/workflows/release-ios.yml` is a Shorebird release workflow. It is not the path for this build.
- After upload: **TestFlight** → add internal testers, smoke-test on a real iPhone (sign-in, swipe, map, 360° tour, delete account) and an iPad.
- When green: App Store Connect → the build → **Add for Review → Submit for Review**. Answer **Export Compliance** (ITSAppUsesNonExemptEncryption=false → "Does not use encryption / exempt").

## 7. Verification checklist (before "Submit for Review")

- [ ] `flutter analyze lib` clean (only the known orphan `feature_flags.dart` error, which isn't compiled).
- [ ] Release build archives & uploads without errors or warnings. `tool/generate_binary_dsyms.sh` covers the prebuilt SwiftPM frameworks, so a missing-dSYM warning is a release-symbol regression (see `docs/dSYM_UPLOAD_RCA.md`).
- [ ] Sign in via **email + password**, **Phone OTP** and **Apple** on a physical iPhone.
- [ ] Google sign-in works on iOS (§1.1).
- [ ] **Account create → Delete Account → confirm the account cannot log back in** (needs `DELETE /api/v1/users/me`, §1.2).
- [ ] Runs correctly on **iPhone** and **iPad 10.2"** + **iPad 12.9"** in portrait **and** landscape (Discover swipe feel, Explore map+panel, Property Details two-pane).
- [ ] Deep link / universal link opens a property (requires §1.3 AASA).
- [ ] Privacy Policy + Terms reachable in-app (Profile → Privacy).
- [ ] App Privacy label, screenshots, demo account, and review notes all filled in App Store Connect.
- [ ] No ATT/IDFA - confirm `NSUserTrackingUsageDescription` is absent from `Info.plist` (§1.5).

---

## 8. Known issues / follow-ups (non-blocking for submission)

- **Golden tests are macOS-only**: `test/visual/*_golden_test.dart` carries `@TestOn('mac-os')` because the baselines are rendered on macOS; Linux CI skips them. Run `flutter test test/visual` locally before a release.
- **SwiftPM minimum-platform footgun**: `flutter pub get` (or `flutter clean` + `pub get`) regenerates `FlutterGeneratedPluginSwiftPackage/Package.swift` with `.iOS("13.0")` (Flutter's hardcoded default). Firebase plugins require `.iOS("15.0")`, so the next Xcode-only build/archive fails with "The package product 'firebase-*' requires minimum platform version 15.0 ... but this target supports 13.0" until you re-run `flutter build ios --config-only` (patches the generated package to the project's 15.0). `tool/verify_ios_release.sh` now fails fast if this regresses.
- **Missing dSYMs for prebuilt SwiftPM frameworks**: App Store Connect reports "Upload Symbols Failed" for FirebaseAnalytics, GoogleAppMeasurement, GoogleAppMeasurementIdentitySupport, MapLibre, RecaptchaEnterpriseSDK or GoogleAdsOnDeviceConversion. Their binary artifacts ship without dSYMs, and `tool/generate_binary_dsyms.sh` (run by the Crashlytics build phase) generates them, so any such warning is a regression. Full RCA and tooling in `docs/dSYM_UPLOAD_RCA.md`; `tool/upload_ios_symbols.sh` uploads every dSYM that exists.
- iOS CI: `.github/workflows/release-ios.yml` is a manual Shorebird release workflow (see `docs/shorebird.md`). There is no Fastlane. The 1.1.0+18 build is manual per §6.
