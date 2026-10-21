# App Store Listing — 360Ghar

Ready-to-paste App Store Connect metadata for **360Ghar** (`com.the360ghar.ghar360`).
Copy is written for the iOS App Store and optimized for ASO (App Store Optimization) in the
India real-estate market. Character limits are noted; everything below is within Apple's limits.

> Sister doc: technical submission steps live in `docs/app-store-release-checklist.md`;
> screenshot design spec lives in `docs/app-store-screenshots.md`.

---

## 0. Quick-reference table

| Field | Value | Limit | Used |
|---|---|---|---|
| App Name | `360Ghar: Real Estate & Homes` | 30 | 28 |
| Subtitle | `Buy, rent & tour flats in 360°` | 30 | 30 |
| Keywords | see §4 | 100 | 99 |
| Promotional Text | see §3 | 170 | ~165 |
| Description | see §5 | 4000 | ~1,900 |
| Primary Category | Lifestyle | — | — |
| Secondary Category | Business *(optional)* | — | — |
| Price | Free | — | — |
| Age Rating | 4+ | — | — |
| Primary Language | English (India) | — | — |

---

## 1. App Name (max 30 chars)

**Recommended:** `360Ghar: Real Estate & Homes` *(28)*

Leads with the brand, then the two highest-volume head terms ("real estate", "homes"), which
become indexed for search. Alternatives:

| Option | Chars | Notes |
|---|---|---|
| `360Ghar: Real Estate & Homes` ✅ | 28 | Best keyword coverage + clean brand. |
| `360Ghar: Buy, Rent Property` | 27 | Action-oriented; indexes buy/rent/property. |
| `360Ghar – Property in 360°` | 26 | Differentiator-forward (the 360° hook). |

Keep the brand token as `360Ghar` (no space) in the store name for compactness; the in-app
display name remains "360 Ghar".

---

## 2. Subtitle (max 30 chars)

**Recommended:** `Buy, rent & tour flats in 360°` *(30)*

Adds **new** keywords not already in the name (buy, rent, tour, flats, 360) — Apple indexes the
subtitle, so it should never repeat name words. Alternatives:

| Option | Chars | Notes |
|---|---|---|
| `Buy, rent & tour flats in 360°` ✅ | 30 | Max keyword pickup + the 360° differentiator. |
| `Swipe to find homes in 360°` | 27 | Highlights the signature swipe UX. |
| `Flats & villas with 360° tours` | 30 | Property-type heavy. |

---

## 3. Promotional Text (max 170 chars — editable any time without review)

```
Step inside every home in immersive 360°. Swipe verified flats, villas & plots, see them on the map, and book a visit in seconds — your dream home starts here.
```

Use this slot for time-sensitive pushes (e.g. "New listings in Gurugram this week") since it
updates without a new build.

---

## 4. Keywords (max 100 chars — comma-separated, NO spaces)

```
property,apartment,house,villa,plot,2bhk,3bhk,housing,realty,broker,agent,pg,room,resale,lease,sale
```
*(99 chars)*

ASO rules applied:
- **No spaces** after commas (spaces waste characters).
- **No repeats** of words already in the App Name (real, estate, homes) or Subtitle (buy, rent,
  tour, flats, 360) — those are already indexed.
- **No competitor trademarks** (e.g. MagicBricks, 99acres, NoBroker, Housing) — Apple can reject
  metadata containing them.
- Singular forms (Apple matches close variants); high-intent India terms (2bhk/3bhk, pg, resale).

If you change the Name/Subtitle, free up the now-duplicated words and add candidates from the
bench: `furnished,society,duplex,studio,builder,tenant,landlord,flatmate,independent`.

---

## 5. Description (max 4000 chars — ready to paste)

```
360Ghar — Find Your Next Home in 360°

House-hunting, reimagined. 360Ghar turns finding a home into something you'll actually enjoy. Swipe through hand-picked flats, apartments, villas and plots, step inside with immersive 360° virtual tours, and see exactly where every property sits on the map — all before you ever step out the door.

Whether you're buying, renting, or just exploring what's out there, 360Ghar helps you discover the right home faster — with less back-and-forth and zero guesswork.

WHY YOU'LL LOVE 360GHAR

• Swipe to discover — Like the homes you love, pass on the ones you don't. Your feed gets sharper with every swipe.
• True 360° virtual tours — Walk through every room in immersive 360°. Really know a place before you visit it.
• Real locations on the map — See the exact location, nearby landmarks and the neighbourhood at a glance.
• Powerful filters — Narrow by budget, BHK, property type, furnishing, amenities and more to see only what fits.
• Save your favourites — Keep every home you've liked in one place and compare them whenever you want.
• Book visits in a tap — Schedule property visits with agents directly inside the app.
• Instant alerts — Get notified the moment a property matching your taste goes live.
• Made for you — Use the app in English or Hindi, in a clean light or dark theme.

BUY • RENT • DISCOVER

From compact 1BHK city apartments to spacious family villas and investment plots, 360Ghar brings rich listings, immersive media and real locations together in one beautifully simple app.

No endless scrolling. No mystery locations. No wasted site visits. Just a faster, smarter, more delightful way to find the place you'll call home.

Your dream home is one swipe away. Download 360Ghar today.

— — —

Questions or feedback? We'd love to hear from you at support@360ghar.com.
```

> Tip: the first 2–3 lines show above the "more" fold on the product page — keep the strongest
> hook there (it already is). Adjust the support email to your live address before submitting.

---

## 6. What's New / Release Notes (max 4000 chars)

For **v1.0.7** (first App Store release):

```
Welcome to 360Ghar! 🏡

• Swipe through hand-picked homes and save your favourites
• Step inside with immersive 360° virtual tours
• See every property's exact location on the map
• Filter by budget, BHK, type, furnishing and amenities
• Book property visits with agents in a tap
• English & Hindi, with light and dark themes

Thanks for downloading — we'd love your feedback at support@360ghar.com.
```

For future updates, lead with user-facing changes; avoid "bug fixes and performance
improvements" alone.

---

## 7. Categories

- **Primary:** Lifestyle *(the standard category for real-estate apps like Zillow / Realtor.com
  — the App Store has no dedicated "Real Estate" category)*
- **Secondary (optional):** Business

---

## 8. Age Rating — target 4+

Run Apple's content questionnaire and answer **No** to every objectionable-content question.
One question needs care:

- **Unrestricted Web Access → No.** The in-app WebView loads only curated 360° tour URLs, not an
  open browser. Answering "Yes" would force a 17+ rating. (If you ever add free web browsing,
  revisit this.)

Result: **4+**.

---

## 9. URLs

| Field | Value | Notes |
|---|---|---|
| Privacy Policy URL *(required)* | `https://360ghar.com/privacy-policy` | Must be live & public. The in-app policy is fetched dynamically from the backend, so verify a public web page exists at this URL before submitting. |
| Support URL *(required)* | `https://360ghar.com/support` | A real page with a contact method (email/form). |
| Marketing URL *(optional)* | `https://360ghar.com` | Brand landing page. |

---

## 10. App Review information

Login is **phone + OTP** (Supabase auth), so App Review **must** be given a way in or the
build will be rejected under Guideline 2.1.

- **Sign-in required:** Yes
- **Provide one of:**
  - A demo account with a test phone number and a **fixed/static OTP** (e.g. phone
    `+91-XXXXXXXXXX`, OTP `123456`), **or**
  - A short-lived real number the reviewer can use, plus instructions.
- **Review Notes (paste & fill in):**
  ```
  Login uses a phone number + SMS OTP. Demo account:
    Phone: +91-XXXXXXXXXX
    OTP:   123456
  After login, the home feed shows properties to swipe. Tap a card to open details and the 360°
  tour (loads over HTTPS — please ensure network access). Location permission is used only to
  show nearby properties on the map (when-in-use). Photo-library permission is used only when a
  user uploads images/videos to a listing. The app does not use tracking/IDFA.
  ```
- **Contact:** name, phone, and email of someone who can answer reviewer questions.

---

## 11. Hindi localization (en-IN primary; add hi as a localization)

The app ships English + Hindi, so add a Hindi (`hi`) App Store localization to lift discovery
and conversion with Hindi-first users. Keep the App Name as `360Ghar` (brand).

| Field | Hindi |
|---|---|
| Subtitle (≤30) | `360° टूर के साथ घर खोजें` |
| Promotional Text | `हर घर में 360° में कदम रखें। फ्लैट, विला और प्लॉट स्वाइप करें, नक्शे पर देखें और एक टैप में विज़िट बुक करें।` |
| Keywords (≤100) | `घर,मकान,फ्लैट,प्रॉपर्टी,किराया,मकान खरीदें,विला,प्लॉट,2bhk,3bhk,दलाल,पीजी,कमरा` |

**Short Hindi description:**
```
360Ghar के साथ घर ढूँढना अब आसान और मज़ेदार। पसंद के फ्लैट, अपार्टमेंट, विला और प्लॉट स्वाइप करें, इमर्सिव 360° वर्चुअल टूर में हर कमरा देखें, और नक्शे पर सटीक लोकेशन जानें — घर से निकले बिना।

खरीदना हो, किराये पर लेना हो या बस देखना हो — 360Ghar आपके लिए सही घर तेज़ी से ढूँढता है।

• स्वाइप करके खोजें  • 360° वर्चुअल टूर  • नक्शे पर असली लोकेशन
• स्मार्ट फ़िल्टर  • पसंदीदा सेव करें  • एक टैप में विज़िट बुक करें

आपका सपनों का घर बस एक स्वाइप दूर है। आज ही 360Ghar डाउनलोड करें।
```

---

## 12. Other App Store Connect fields

| Field | Value |
|---|---|
| Bundle ID | `com.the360ghar.ghar360` |
| SKU | `ghar360-ios-001` *(any unique internal string)* |
| Apple Team ID | `HMWGCVU4SV` |
| Price | Free |
| In-App Purchases | None |
| Availability | India (primary); expand to other regions as desired |
| Content Rights | Does **not** contain third-party content (confirm) |
| Copyright | `© 2026 360Ghar` *(replace with the legal entity name, e.g. "© 2026 <Company> Pvt. Ltd.")* |
| Routing App Coverage | N/A |

---

## 13. Screenshots & assets (summary)

Full design spec: `docs/app-store-screenshots.md`. Required for upload:

- **6.9"/6.7" iPhone** (e.g. 1290×2796) — **required**, 3–10 shots.
- **6.5" iPhone** — recommended fallback for older display sizes.
- **12.9"/13" iPad** — only if the app is offered on iPad.
- App icon is already in the build (1024×1024 marketing icon present in the asset catalog).
- Suggested shot order (story arc): Swipe discovery → 360° tour → Map with exact location →
  Filters → Saved/Liked homes → Book a visit → Profile/EN-Hindi & dark mode.

---

## 14. Pre-submission copy checklist

- [ ] App Name ≤30, Subtitle ≤30, Keywords ≤100 (no spaces, no competitor brands).
- [ ] Description proofread; support email is live.
- [ ] Privacy Policy URL resolves to a public page.
- [ ] Support URL resolves and has a contact method.
- [ ] Demo account / static OTP filled into Review Notes.
- [ ] Age rating questionnaire completed → 4+ (Unrestricted Web Access = No).
- [ ] Hindi localization added (optional but recommended).
- [ ] Copyright legal entity finalized.
- [ ] Screenshots uploaded for every supported device size.
- [ ] App Privacy "nutrition label" answers match `ios/Runner/PrivacyInfo.xcprivacy`
      (see `docs/app-store-release-checklist.md` §5).
```
