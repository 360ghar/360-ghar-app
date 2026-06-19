# ghar360 — iOS App Store Submission Guide

End-to-end checklist for shipping **ghar360** (`1.0.7+12`, bundle `com.the360ghar.ghar360`, iOS 15.0+, team `HMWGCVU4SV`) to the App Store. Work top-to-bottom. Items marked **[external]** must be done outside this repo (browser / console / backend).

> Companion: `docs/ACCOUNT_DELETION_CONTRACT.md` (the backend endpoint the app depends on).

---

## 0. Status of code-level readiness (done in this workstream)

- ✅ Account-deletion works end-to-end on the client (`POST /auth/delete-account`; type-`DELETE` confirm dialog; reactive loading; errors via `ErrorHandler`). **Depends on the backend endpoint — see §1.2.**
- ✅ Responsive foundation + 9 screens adapted for iPad (rail-free; bottom-nav kept by choice; content centered/capped; responsive grids; two-pane Property Details & Explore).
- ✅ Info.plist, entitlements, app icon, launch screen, deployment target — all verified (`plutil -lint` clean).
- ✅ Google sign-in hidden on iOS (v1 fallback) so the placeholder URL scheme can't crash — see §1.1 to enable real Google sign-in later.
- ⚠️ Pre-existing repo issues that do NOT block submission but should be cleaned: `lib/core/utils/feature_flags.dart` orphan compile error (not imported — won't break the build) and ~105 errors in `test/` (broken scaffolding; not compiled into release).

---

## 1. External pre-flight (do these in parallel with the build)

### 1.1 Google Sign-In on iOS — create an iOS OAuth client **[external]**
iOS cannot reuse the Web/Android OAuth client for the native redirect. In the **same Google Cloud project** you use for Web/Android:
1. **APIs & Services → Credentials → Create credentials → OAuth client ID → iOS**.
2. Bundle ID: `com.the360ghar.ghar360`.
3. Copy the **iOS client ID** (`…apps.googleusercontent.com`).
4. To enable real Google sign-in later: (a) put the **reversed** iOS client ID into `ios/Runner/Info.plist` (the `com.googleusercontent.apps.…` URL scheme at the `google-sign-in` entry, currently a placeholder), (b) pass `clientId:` (iOS) and `serverClientId:` (your existing **Web** client ID — this is what the backend verifies, and it IS shared across platforms) where `GoogleSignIn(...)` is constructed, (c) remove the `!Platform.isIOS` guard in `lib/features/auth/presentation/views/phone_entry_view.dart`.
   - Until you do this, Google is hidden on iOS and the app is fully submittable.

### 1.2 Account-deletion backend endpoint **[external — backend team]**
Implement `POST /api/v1/auth/delete-account` (authenticated, bearer session token). See `docs/ACCOUNT_DELETION_CONTRACT.md`. Server must hard-delete **or** soft-delete (`deleted_at` + revoke all sessions/refresh tokens + block future auth) so the account is **unusable after deletion** (Apple verifies this). Without it, deletion surfaces a 404 and the app will be rejected.

### 1.3 Universal Links — host the AASA file **[external — web/infra]**
The app declares `applinks:` for `the360ghar.com`, `www.the360ghar.com`, `app.the360ghar.com` and `webcredentials:360ghar.com`. Each domain must serve a valid **apple-app-site-association** JSON at:
- `https://<domain>/.well-known/apple-app-site-association` **and** `https://<domain>/apple-app-site-association`
containing team ID `HMWGCVU4SV`, bundle id `com.the360ghar.ghar360`, under `applinks` and `webcredentials`. If missing, universal links silently fail (property deep links won't open the app).

### 1.4 Restrict the Google Places API key **[external — security]**
`GOOGLE_PLACES_API_KEY` is bundled in the client. In Google Cloud Console → **APIs & Services → Credentials**, restrict that key to **iOS** with bundle ID `com.the360ghar.ghar360` (and Android with your Android package) so it can't be abused. (Supabase anon key is public-by-design — just confirm **RLS policies** are enabled on all tables.)

### 1.5 ⚠️ Firebase Analytics + ATT (tracking) — VERIFY **[external]**
Firebase Analytics collects the **IDFA by default** on iOS. If it does, the app performs "tracking" and you MUST:
- Add `NSUserTrackingUsageDescription` to `Info.plist` (e.g. "This identifier enables a better, personalized experience across the app and partner services."), and
- Show the App Tracking Transparency prompt at runtime, and
- declare "Identifiers • Advertising ID • Used for Tracking" in the App Privacy label.
**OR** disable IDFA collection in Firebase (set `GOOGLE_ANALYTICS_COLLECTION_AD_ID_ENABLED = NO` in `ios/Runner/Info.plist`, or use the no-ad-id Firebase Analytics pod). **Decide before submission** — this affects whether ATT is required. Crashlytics and Performance are NOT tracking.

---

## 2. App Store Connect — app metadata **[external]**

Create the app record (My Apps → + → New App, iOS, bundle `com.the360ghar.ghar360`, SKU, primary language English).

- **Name**: `360 Ghar` (or the final brand name; must be unique). **Subtitle** (30 chars): e.g. `Swipe, tour & find your home`.
- **Description** + **Keywords** (100 chars, comma-separated) + **Promotional text**.
- **Support URL** + **Marketing URL** (must be live HTTPS pages — can be `the360ghar.com` pages).
- **Privacy Policy URL** (required): the app loads it from `api.360ghar.com/pages/privacy-policy/public`; App Store Connect still needs a **public web URL** — host the same content at e.g. `https://the360ghar.com/privacy-policy`.
- **Category**: Primary `Lifestyle` (or `Real Estate` if available), Secondary optional.
- **Age rating**: answer the questionnaire — unrestricted web access = No (the WebView only opens 360° tour URLs, not general browsing), no UGC/gambling/violence → **4+**.
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
| Diagnostics | Crash / Performance | Yes (Crashlytics, Performance) | App Functionality | No (or per your config) |
| Identifiers | Advertising ID | **Only if §1.5 ATT path is taken** | Tracking | — |

**Third-party SDKs** ( disclose in the SDK section): Supabase, Firebase (Analytics/Crashlytics/Messaging/Remote Config/Performance), MapLibre, Cloudinary (via backend), Google Places/Sign-In.

**Account deletion**: answer **Yes** to "account deletion" (the app offers it — see §1.2). **Data retention**: state your policy.

## 4. Screenshots **[external]**

Required device sizes (App Store Connect). Capture from simulators at full resolution (File → Save Screen), or fastlane `snapshot`.
- **6.7"** (iPhone 15 Pro Max) — required.
- **6.5"** or **6.1"** (iPhone 14 Plus / 15) — required set.
- **iPad 12.9"** (6th gen) — **required** because the app supports iPad.
- Optional: **5.5"**, and a **30-sec app preview video** per size.
Recommended shots: Discover swipe deck, Explore map, Property details + 360° tour, Likes, Visits, Profile. For iPad, show the two-pane Property Details and the map side-panel to demonstrate tablet polish.

## 5. App Review Information **[external]**

- **Demo credentials**: provide a **test phone number + the OTP the reviewer should enter** (or a number that always receives OTP), since sign-in is phone-OTP-based. If you use a fixed dev OTP in non-prod, make sure the **production** build the reviewer gets lets them actually sign in — or provide a dedicated review account.
- **Notes**: describe the core flow — "Browse properties by swiping (Discover), view the map (Explore), open a property to see the 360° virtual tour (WebView), save (Likes), and request a visit (Visits). Account can be deleted from Profile → Privacy → Delete Account."
- **Contact**: name, email, phone.

## 6. Build & upload **[you — on a Mac with Xcode]**

```bash
# 1. Resolve deps
flutter clean
flutter pub get
cd ios && pod install && cd ..

# 2. Build the release (Dart + native compile check)
flutter build ios --release

# 3. Open Xcode and archive
open ios/Runner.xcworkspace
#   Xcode: select the "Runner" scheme, device target = "Any iOS Device (arm64)"
#   Product → Archive
#   In Organizer: Distribute App → App Store Connect → Upload
#     (automatic signing, team HMWGCVU4SV; matches ios/ExportOptions.plist
#      method=app-store-connect, uploadSymbols=true)
```
- After upload: **TestFlight** → add internal testers, smoke-test on a real iPhone (sign-in, swipe, map, 360° tour, delete account) and an iPad.
- When green: App Store Connect → the build → **Add for Review → Submit for Review**. Answer **Export Compliance** (ITSAppUsesNonExemptEncryption=false → "Does not use encryption / exempt").

## 7. Verification checklist (before "Submit for Review")

- [ ] `flutter analyze lib` clean (only the known orphan `feature_flags.dart` error, which isn't compiled).
- [ ] Release build archives & uploads without errors/warnings.
- [ ] Sign in via **Phone OTP** and **Apple** on a physical iPhone.
- [ ] Google button hidden on iOS (expected for v1) — or, if §1.1 done, Google sign-in works.
- [ ] **Account create → Delete Account → confirm the account cannot log back in** (requires §1.2 backend).
- [ ] Runs correctly on **iPhone** and **iPad 10.2"** + **iPad 12.9"** in portrait **and** landscape (Discover swipe feel, Explore map+panel, Property Details two-pane).
- [ ] Deep link / universal link opens a property (requires §1.3 AASA).
- [ ] Privacy Policy + Terms reachable in-app (Profile → Privacy).
- [ ] App Privacy label, screenshots, demo OTP, and review notes all filled in App Store Connect.
- [ ] ATT decision resolved (§1.5).

---

## 8. Known issues / follow-ups (non-blocking for submission)

- `lib/core/utils/feature_flags.dart` references `RemoteConfigService.getFlag` which doesn't exist — pre-existing WIP; fix or remove.
- `test/` contains broken scaffolding (`mocktail` references, `DebugLogger.setContext`, `test/helpers/mocks.dart`) — 105 analyze errors; not compiled into release. Clean up before enabling CI test gates.
- No iOS CI/Fastlane (out of scope this cycle; manual build per §6).
- Re-enable real Google sign-in on iOS when ready (§1.1).
