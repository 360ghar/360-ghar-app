# App Store Release Checklist — 360 Ghar (iOS)

A practical, end-to-end checklist for shipping **360 Ghar** to the Apple App Store.
Work top to bottom; every box should be checked before you hit **Submit for Review**.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Apple Developer / App Store Connect Setup](#2-apple-developer--app-store-connect-setup)
3. [Push Notifications (APNs)](#3-push-notifications-apns)
4. [Universal Links](#4-universal-links)
5. [Privacy](#5-privacy)
6. [Export Compliance](#6-export-compliance)
7. [Build & Upload](#7-build--upload)
8. [Store Listing & Assets](#8-store-listing--assets)
9. [Pre-Submission QA Checklist](#9-pre-submission-qa-checklist)
10. [Common Rejection Risks](#10-common-rejection-risks)

---

## 1. Overview

| Field | Value |
| --- | --- |
| App name | **360 Ghar** |
| Bundle ID | `com.the360ghar.ghar360` |
| Apple Team ID | `HMWGCVU4SV` |
| Current version | `1.0.7+12` (marketing `1.0.7`, build `12`) |
| Minimum iOS | `15.0` |
| Firebase project | `ghar-3c690` |
| Universal Link domains | `the360ghar.com`, `www.the360ghar.com`, `app.the360ghar.com` |
| Bitcode | Disabled (`ENABLE_BITCODE = NO`) |

**Tech that drives review/privacy answers:** Firebase (FCM / Crashlytics / Analytics /
Performance / Remote Config / App Check), Supabase, geolocator (when-in-use / precise location
only), image_picker (photo library only — no camera), MapLibre, webview_flutter.
**No** App Tracking Transparency, **no** IDFA, **no** cross-app tracking.

---

## 2. Apple Developer / App Store Connect Setup

- [ ] Apple Developer Program membership is **active** under Team `HMWGCVU4SV`.
- [ ] You have a role of **Admin** or **App Manager** in App Store Connect (needed to create the app record and submit).
- [ ] Create the **App Store Connect app record** for `com.the360ghar.ghar360`:
  - [ ] App Store Connect → **My Apps → +** → **New App**.
  - [ ] Platform: **iOS**; Name: **360 Ghar**; Primary language; SKU; Bundle ID `com.the360ghar.ghar360`.
  - [ ] If the Bundle ID is not in the dropdown, register it first under **Certificates, Identifiers & Profiles → Identifiers**, enabling the **Push Notifications** and **Associated Domains** capabilities.
- [ ] Signing (managed automatically by Xcode, since `DEVELOPMENT_TEAM` is now set):
  - [ ] Xcode → **Settings → Accounts** is signed in with an account on Team `HMWGCVU4SV`.
  - [ ] Runner target → **Signing & Capabilities** → **Automatically manage signing** is ON; Team = `HMWGCVU4SV`.
  - [ ] Xcode auto-creates the **Apple Distribution** certificate and an **App Store** provisioning profile that include the **Push Notifications** and **Associated Domains** capabilities. Confirm both capabilities are listed under Signing & Capabilities.
  - [ ] (Manual fallback only if not using automatic signing) Create an **Apple Distribution** certificate and an **App Store** provisioning profile for `com.the360ghar.ghar360` that include Push Notifications + Associated Domains.

---

## 3. Push Notifications (APNs)

The app's `aps-environment` entitlement is set to **`production`** for release builds, so a
production APNs path must exist or push will silently fail.

- [ ] Confirm the **iOS app is registered in Firebase** (project `ghar-3c690`) with bundle id `com.the360ghar.ghar360`, and that `GoogleService-Info.plist` in the build matches that app.
- [ ] In **Firebase Console → Project Settings → Cloud Messaging → Apple app configuration**, upload a **production APNs Authentication Key (.p8)**:
  - [ ] Create the key in **Apple Developer → Certificates, Identifiers & Profiles → Keys** with the **Apple Push Notifications service (APNs)** capability enabled (a single .p8 works for both sandbox and production).
  - [ ] Record the **Key ID** and your **Team ID** (`HMWGCVU4SV`) when uploading to Firebase.
- [ ] Verify end-to-end: send a test push from Firebase / your backend to a **TestFlight (production aps-environment)** build on a physical device and confirm receipt.

> Note: Push tokens minted by a release/TestFlight build are **production** tokens and will not work against the APNs sandbox. Test push with a TestFlight build, not a debug build, to validate the production path.

---

## 4. Universal Links

Entitlements declare `applinks:the360ghar.com`, `applinks:www.the360ghar.com`, and `applinks:app.the360ghar.com`. Apple validates the
`apple-app-site-association` (AASA) file hosted on those domains — it is **not** in this repo and
must be hosted by the web/infra team.

- [ ] Host the AASA file at **both**:
  - `https://the360ghar.com/.well-known/apple-app-site-association`
  - `https://www.the360ghar.com/.well-known/apple-app-site-association`
  - `https://app.the360ghar.com/.well-known/apple-app-site-association`
- [ ] Requirements for each:
  - [ ] Filename is exactly `apple-app-site-association` (**no** `.json` extension).
  - [ ] Served over **HTTPS** with `Content-Type: application/json`.
  - [ ] **No redirects** (return `200` directly, not a 301/302 to another URL).
  - [ ] Valid JSON; `appID` = `HMWGCVU4SV.com.the360ghar.ghar360` (TeamID.BundleID).
- [ ] Validate after deploy with Apple's CDN-cached fetch (`https://app-site-association.cdn-apple.com/a/v1/the360ghar.com`) and by tapping a real `https://the360ghar.com/...` link on a device with the app installed.

**Example AASA JSON (`applinks` section):**

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "HMWGCVU4SV.com.the360ghar.ghar360",
        "paths": ["*"]
      }
    ]
  }
}
```

> Modern format alternative (also valid): replace `"appID"` with `"appIDs": ["HMWGCVU4SV.com.the360ghar.ghar360"]` and `"paths"` with a `"components"` array. Keep the path rules in sync with the routes your `DeepLinkService` actually handles.

---

## 5. Privacy

### 5a. Privacy policy URL (REQUIRED)

- [ ] A **public, live privacy-policy URL** is entered in App Store Connect → App Privacy → **Privacy Policy URL** (App Store Connect requires a publicly reachable URL; it does not accept an in-app-only policy).
- [ ] Note: the in-app policy is fetched **dynamically from the backend** (see `lib/features/profile/.../privacy_view.dart` and `policy_page_view.dart`), so confirm a corresponding **public web URL** (e.g. `https://the360ghar.com/privacy`) is live and returns the same content.

### 5b. App Privacy "nutrition label"

These answers must **exactly match** `ios/Runner/PrivacyInfo.xcprivacy` (`NSPrivacyTracking = false`).
For every type below: **Linked to user = No**, **Used for tracking = No**.

| Data type | Collected | Linked to user | Used for tracking | Purpose(s) |
| --- | --- | --- | --- | --- |
| Precise Location | Yes | No | No | App Functionality |
| Crash Data | Yes | No | No | App Functionality (diagnostics) |
| Performance Data | Yes | No | No | App Functionality (diagnostics) |
| Other Diagnostic Data | Yes | No | No | App Functionality (diagnostics) |
| Product Interaction | Yes | No | No | Analytics |
| Device ID | Yes | No | No | App Functionality, Analytics |

> In App Store Connect, "Crash Data / Performance Data / Other Diagnostic Data" map to the **Diagnostics** category with purpose **App Functionality**; "Product Interaction" maps to **Usage Data** with purpose **Analytics**; "Device ID" maps to **Identifiers** with purposes **App Functionality + Analytics**.

- [ ] App Store Connect privacy answers entered and verified against the table above.
- [ ] **App Tracking Transparency (ATT) is NOT used** — there is no `NSUserTrackingUsageDescription`, no `AppTrackingTransparency` prompt, and no IDFA collection. Do **not** answer "Yes" to any "used to track you" question.

---

## 6. Export Compliance

- [ ] `ITSAppUsesNonExemptEncryption = false` is set in `Info.plist` (the app uses only standard
      HTTPS/TLS and Keychain, which are **exempt** uses of encryption).
- [ ] Because that key is present, the per-submission **encryption** question in App Store Connect is auto-answered — no annual self-classification (CCATS/year-end report) is required for exempt usage.

---

## 7. Build & Upload

### Pre-build

- [ ] `flutter clean && flutter pub get`
- [ ] Confirm iOS uses Swift Package Manager (no `pod install`; plugins resolve via SPM)
- [ ] Confirm `pubspec.yaml` version is `1.0.7+12` (or bumped — see policy below).

### Build the IPA

```bash
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

- Artifact lands in **`build/ios/ipa/`** (e.g. `build/ios/ipa/ghar360.ipa`).
- The archive is also written under `build/ios/archive/`.

### Upload to App Store Connect (choose one)

- [ ] **Transporter app** (simplest): drag `build/ios/ipa/*.ipa` in and **Deliver**.
- [ ] **Xcode Organizer**: build/archive in Xcode → **Distribute App → App Store Connect → Upload**.
- [ ] **CLI with App Store Connect API key** (CI-friendly):
  ```bash
  xcrun altool --upload-app -f build/ios/ipa/ghar360.ipa -t ios \
    --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
  ```
  (Create the API key under App Store Connect → **Users and Access → Integrations → App Store Connect API**.)

### Build-number policy

- [ ] Current build is `+12`. **Every subsequent upload must bump the build number** (`+13`, `+14`, …)
      in `pubspec.yaml` — App Store Connect rejects a re-upload that reuses a build number for the same marketing version.
- [ ] Bump the marketing version (`1.0.7` → `1.0.8` / `1.1.0`) when shipping a new user-facing release.

### After upload

- [ ] Wait for processing to finish in App Store Connect (a few minutes to ~1 hr).
- [ ] Confirm dSYMs uploaded (Crashlytics symbolication) — `uploadSymbols` is `true` in `ExportOptions.plist`.
- [ ] Select the processed build under the app version, complete metadata, and **Submit for Review**.

---

## 8. Store Listing & Assets

- [ ] **App name:** 360 Ghar
- [ ] **Subtitle:** short value prop (≤ 30 chars), e.g. "360° home tours & discovery".
- [ ] **Promotional text** (optional, editable without resubmission).
- [ ] **Description:** full marketing copy (features: swipe discovery, 360° virtual tours, map exploration, visit scheduling).
- [ ] **Keywords:** comma-separated, ≤ 100 chars (e.g. `real estate,property,360 tour,home,rent,buy,virtual tour,flat`).
- [ ] **Support URL** (required) and **Marketing URL** (optional) — point to live pages on `the360ghar.com`.
- [ ] **Category:** Primary **Lifestyle** (Real Estate is not a top-level App Store category; choose Lifestyle, optionally secondary **Utilities**/**Travel**).
- [ ] **Age rating:** complete the questionnaire (no objectionable content expected → likely **4+**).
- [ ] **Screenshots:** produce per the existing spec — see [`docs/app-store-screenshots.md`](./app-store-screenshots.md). Do not duplicate that spec here.

  Required device sizes:

  | Device class | Resolution (portrait) | Required? |
  | --- | --- | --- |
  | 6.9" / 6.7" iPhone | `1290 × 2796` | Yes |
  | 5.5" iPhone | `1242 × 2208` | Only if supporting older devices |
  | 12.9" iPad Pro | `2048 × 2732` | Only if shipping an iPad build |

- [ ] **App icon** present in asset catalog at all required sizes (no alpha/transparency).

---

## 9. Pre-Submission QA Checklist (physical device, release/TestFlight build)

- [ ] **Photo upload:** triggering image picker shows the new **photo library** permission prompt string (and there is **no** camera prompt).
- [ ] **Location:** location feature shows the **when-in-use** ("while using the app") prompt — confirm there is **no** "Always Allow" option/string.
- [ ] **Push notifications:** receive a **production** push on a TestFlight build (validates the production aps-environment + APNs .p8).
- [ ] **Deep link:** tapping a `https://the360ghar.com/...` link opens the app to the correct screen (Universal Link / AASA working).
- [ ] **360 tour:** webview tour loads over **HTTPS** and renders correctly (no ATS / mixed-content failures).
- [ ] **Cold start:** splash screen shows correct branding; app reaches the auth/home flow without crashing.
- [ ] **Run quality gates:** `flutter analyze` clean; `dart format .` applied; `flutter test` passing.

---

## 10. Common Rejection Risks

- [ ] **Over-permissioned location** — *fixed*: the "Always" usage string was removed; only when-in-use/precise is requested. Verify no stray `NSLocationAlwaysAndWhenInUseUsageDescription` remains.
- [ ] **Missing privacy manifest** — *fixed*: `ios/Runner/PrivacyInfo.xcprivacy` is present and matches the nutrition-label table in §5b.
- [ ] **Mismatch between privacy manifest and App Store Connect answers** — keep §5b and `PrivacyInfo.xcprivacy` in sync; Apple cross-checks them.
- [ ] **Reviewer cannot log in** — the app uses **phone / OTP** login. Provide the App Review team, in **App Review Information → Notes**, either:
  - [ ] a **reviewer test account** (a phone number you control + the OTP, or a fixed test OTP/bypass), or
  - [ ] clear steps + a working demo number so the reviewer can complete sign-in.
  - [ ] Mark **Sign-in required = Yes** and fill the demo credentials fields.
- [ ] **Universal Links not resolving** — caused by AASA redirect/wrong Content-Type/missing `.well-known`; re-verify §4 before submitting.
- [ ] **Incomplete metadata / placeholder URLs** — ensure Support/Privacy URLs are live, not staging.
