# Design law check

This file checks the app against the design law in `~/.claude/CLAUDE.md`, one point at a time,
after the Paper Cut Diorama redesign, its second pass (1 October 2026: Erode type, the three-hue palette and colour paper art) and the third pass (1 October 2026: the paper city on every screen).

Status values: **pass** (the app does not have the tell), **fixed** (a tell was found during this
review and removed), **override** (the user asked for it), **n/a** (the pattern does not exist in
an app of this kind).

Evidence is a file, a golden in `test/visual/goldens/`, or a simulator capture. Goldens are
listed without the `.png` suffix.

## User overrides

| Point | Decision |
|---|---|
| Saturated accent colour | The brand marigold `#F5B400` is the action colour (user decision). It fills only the one primary button per area. The user also asked for more colour in the graphics: the scenes now use a multi-colour paper palette. In the UI, the second accent is a deep, tonal peacock teal (`#0C6A61` by day) for icons, links and chosen states; it never fills a large area. |

## Tells

| Point | Status | Evidence |
|---|---|---|
| Lucide / stock icon pack | pass | 0 Material `Icons.*` in `lib/`. 87 knife-cut polygon icons (`knife_icons.dart`), drawn for the paper system. |
| Em dashes | fixed | 0 in the message catalogue. The About screen showed `'—'` for a missing version; it now says "Unavailable". The contract doc used `—` for empty cells; now "none". |
| Pill / eyebrow badge | pass | No eyebrow above any heading. Metadata is text with `·` separators. |
| Fraunces + Work Sans, Space Grotesk, Sora, Syne, Archivo, Inter, Cormorant, Didones, JetBrains Mono | fixed | The user rejected Quilon. Display is now Erode (Fontshare, ITF licence, self-hosted, low-contrast serif, not a Didone), chosen from 14 rendered candidates; Hindi display falls back to Noto Serif Devanagari. Body: Manrope with Noto Sans Devanagari. |
| Glowy pill buttons | pass | Buttons are flat, 12 px radius, no glow, no shadow. Hover and press change colour only. |
| Oversized icon in a coloured tile | fixed | Removed from Profile, Tools, Visits (thumbnail tile became a date block), Explore loading (a 100 px map icon became a plain surface with a progress bar). |
| Floating cards | pass | Nothing bobs or loops. The only ambient motion is the onboarding diorama's finite 5 s moment. |
| Cut-off glow | pass | No glow anywhere. |
| Kitchen-sink card | pass | Property rows: photo, price, title, one `·` line. No tiles, chips, dividers or glowing buttons. |
| Fake macOS / app window, fake code window | n/a | Not in the app. |
| Purple and blue-purple gradients | pass | No gradients. UI: marigold, peacock teal, brick, neem ink; night is a green-black, not blue (`app_design_tokens.dart`). |
| Gradient pill with icon and text | pass | None. |
| Default CTA button pair (fill + outline) | pass | One primary per area. The secondary is a tonal slip or an ink text button, never an outline. Apple and Google sign-in follow the platform brand rules. |
| Three-tier pricing, testimonial card, decorative quote marks, countdown timer, pre-footer CTA banner | n/a | Not in the app. |
| Gradient-circle initials avatar | pass | The Profile placeholder is a flat mint circle with one Erode initial, no gradient (`profile_content_*`). |
| Logo lockup (gradient tile + wordmark) | fixed | The splash mark sat on a baked beige tile and a gray square. It is now cut out to a transparent mark with a dark variant (`assets/icons/splash_logo*.png`, `logo_mark*.png`). About uses the bare mark. |
| Split hero, default hero stack, hero stack with a right panel | pass | Onboarding is one full-screen diorama with a cut sheet below; auth is a skyline strip over a cut sheet. Neither is the eyebrow–headline–two-buttons stack. |
| Grid / graph-paper background | pass | No grid. Backgrounds carry fine grain only (`paperGrainTile`). |
| Crude CSS/SVG illustrations | pass | The scenes are the website's hand-cut paper art, ported exactly (`paper_scene_data.dart`, fixture-tested against the TypeScript). |
| Accent-bar card | fixed | The gold bar beside property-details section headings is gone (`SectionTitle`). |
| Background glow, radial halo, candy gradients, blobs | pass | None. The sun in the scenes is a flat paper disc. |
| Floating tag pinned to an image | fixed | The "360° / Video / Floor plan" pills on the gallery are now bare text with shadows. |
| Gradient-filled headline text | pass | None. |
| Hairline light border on boxes | fixed | Bordered and shadowed info, location and media cards on property details are flat. |
| Card hover-lift, hover boop | fixed | `AnimatedTapWrapper` no longer scales; it dims while pressed. Buttons never move. |
| Letterspaced serif wordmark, mono house voice, one label treatment everywhere | fixed | No tracked caps. The Profile section labels `ACCOUNT` / `SUPPORT` became "Account" / "Support". Mono is not used. |
| Botched glass | fixed | The glass auth shell and `FrostedGlassContainer` are deleted. |
| Botched fill animations, underline-fill hovers | pass | No animated underlines. The segmented control's slip slides under the chosen tab with stable caps. |
| Content hidden behind an entrance animation | fixed | `ScrollRevealWidget` (8 sections at opacity 0) deleted. The boot loader faded its content in from opacity 0; now static. Profile's fade-in switcher removed. |
| Content sliced by an edge ("clear the cut") | fixed | The Explore empty panel covered and sliced the map controls; it now takes the list sheet's place. Cut sheets pad content by more than their `amp` (`PaperSheet` asserts it). |
| Misaligned parallel columns | pass | The Discover Pass/Like pair shares one height (`IntrinsicHeight`). Fact grids share a baseline per row. |
| Text jammed against the edge | pass | Every screen has a 16–20 px gutter; checked at 320 px in every golden. |
| Default all-around shadow, faked shadow box, bloom of the element's own shape | pass | One shadow helper, `paperShadows`: a contact line plus one directional drop, tinted to the surface below. No ad-hoc `BoxShadow` outside `paper_chrome.dart`. |
| Content flung to the far edges | fixed | At 834 px the Saved and Visits lists stretched edge to edge; they now sit in a centred column (`MaxContentWidth`). |
| Missing or faked logos | pass | The Google button uses the official mark; Apple uses the platform button. No invented logos. |
| Nothing is actually centred | fixed | `PaperIcon` stretched its mark when a parent forced a larger box (the search icon rendered at 44 px). It now centres the mark like `Icon` (`paper_icon_test.dart`). |
| Icon or logo with a box behind it | fixed | See the icon tile and logo rows above. |
| Eyebrow tick, unrounded hairline rules | fixed | The Visits tab bar rule, the two-pane `VerticalDivider`, the Saved actions divider and the booking bar's top border are gone. The booking bar is now a cut card-stock strip (`PaperStrip`), like the navigation bar. |
| Oversized footer wordmark | n/a | No footer. |
| Colliding colours, hard seams | pass | One system: marigold (action), teal (chosen), brick (heart) on neem ink. The scene papers come from one place (a Gurugram street: sandstone, terracotta, neem greens, hazy teal, marigold) and share the UI's teal and marigold. The onboarding and auth skies use the same mint tone as the vignettes, so art and chrome join without a seam. |
| Text with no contrast | pass | `app_design_theme_test.dart` computes contrast in both themes for the new palette: every text colour and the teal accent on every surface, the mint slip and the amber notice ≥ 4.5:1; the label on marigold 8.8:1; field borders, the focus ring and the caution icon ≥ 3:1. Tables in `docs/design-system.md`. |
| Dot under the active nav item | pass | The active tab has a gold-ink icon and a bold label only. |
| Content clipped where sections overlap | fixed | Explore empty state, see above. |
| Cramped display type | pass | Erode at line height 1.25, no negative tracking; prices keep their natural spacing (`₹85 L`). |
| Grain on top of content | pass | Grain is painted under the art and never over text or controls. |
| Cool blue-charcoal dark | pass | Night surfaces are a green-black (`#0F2826` and the `night*` steps in `app_design_tokens.dart`), chosen to carry the teal accent and the marigold action; the law names green-black as a valid dark. |
| Cream / beige page, slop gray | fixed | The page is white by day. `warmCream` and the gray-100 family are gone. The native splash still used `#f9fafb` / `#121417`; regenerated to the sky colours `#DDEFE9` / `#0F2826` (the current first-frame colours). Mint `#E6F2EE` and amber `#FFF4D1` appear only as small tonal slips (selected tab, second button, caution note). |
| Default Google font rotation | pass | The signature face is Erode (Fontshare). Manrope stays as the quiet body face; the Noto Devanagari faces only carry Hindi glyphs. |
| Inner-glow box, pulsing live dot | fixed | The Explore marker pulse is removed; markers are still paper slips. |
| Off-centre strike line | fixed | The document checklist no longer strikes text; done rows use a real checkbox. |
| Fixed background following the scroll | pass | None. |
| Hard image seams | pass | Photos sit inside cut cards or under a scrim. The property photo header meets the white content where the header collapses: this is kept on purpose (a dense screen). |
| Sun-and-moon theme toggle | pass | Theme is chosen in Preferences with the theme dialog. |

## Layouts

| Point | Status | Evidence |
|---|---|---|
| Kicker + H2 section heads, small-label-over-big-heading | pass | Sections open with a `SectionTitle` in the display face, no kicker. |
| Big serif statement, inset enquire island, email pill form, image card with overlay caption | n/a | Not in the app. |
| Flat fill under everything after the hero | fixed | Third pass. The page is the onboarding sky on every screen; content sits on white card stock that rises over a scene header per tab (Saved facade, Visits gate, Profile home, Assistant kite, skyline strip on sub-pages and calculators). Discover's deck overlaps a paper city; Explore's map has a cut page edge. Goldens `saved_content_*`, `visits_content_*`, `profile_content_*`, `discover_content_*`. |
| Multi-line headline | pass | Display lines stay at two lines in English. Hindi at 2× text wraps by necessity. |
| Numbered steps on a rail | pass | None. |
| Tinted pill chips everywhere | fixed | Highlights, amenities, statuses and counts are text. Filter choices keep a selectable shape without a coloured ring. |
| Dead controls | fixed | Help had three controls that only showed a developer toast; removed. Every control in the goldens and the simulator flows responds. Web: Retry re-runs the start-up. |

## Signature

| Point | Evidence |
|---|---|
| One signature artefact | The animated Gurugram diorama in onboarding: paper layers that fold up like card stock, parallax on swipe, gyroscope tilt (`gurugram_diorama.dart`; simulator captures). |
| Atmosphere | Paper grain, colour card-stock scenes by day and a lit city under a teal night, the cut-edge chrome. |
| Layered depth | Diorama layers at five depths; the deck of three cut cards in Discover. |
| Character display type | Erode for headings, prices and big numbers; a matching serif Devanagari for Hindi. |
| One bespoke silhouette | One cut language: the roofline nav with a tower over the active tab, folder tabs cut into the sheet lip, the visit pass with a punched perforation, the torn receipt under calculator results, the listing print with a cut label over the photo. |
| Treated nav | The strip's top edge is a Gurugram roofline; one taller tower slides to the active tab (lit window at night). The rail carries the same roofline on its side. Goldens `navigation_bar_*`, `navigation_rail_*`. |
| Real specifics | Gurugram sectors, the Rapid Metro, a green CNG auto, gulmohar trees, a chai stall, a black water tank, a white milestone with a marigold cap, prices written the Indian way (`₹85 L`, `₹1.25 Cr`). |
| Motion that responds | Swipe-driven fold, deck drag and stamp, header parallax from scroll, the sliding nav tower and folder tab, counts that run from their last value, the photo Hero from a card to the details gallery, the paper slide between pages on Android and web. Reduced motion stops all of it. |

## Checked but not changed

- (Fixed in the third pass) The property-details photo header met the page with a straight edge;
  the body sheet's hand-cut lip and the section tabs now sit over the photo's foot.
- The 834 px Profile uses the medium content width (600 px) and is centred.

## Second pass (1 October 2026)

- The user said the UI and the font looked bad and asked for more colour in the graphics. Changes: Erode replaces Quilon; the palette splits into three roles (marigold action, teal chosen, brick heart) on green-black neutrals; every scene element is its own coloured card stock; the onboarding home has glass windows, a parapet and a water tank.
- Found and fixed in the same pass: the refresh-failure note stacked its Retry under the text at 390 px and read as bare text; it is now an amber note with Retry inline. Prices showed a trailing `.0` (`₹85.0 L`); the formatter now trims it and promotes 100 lakh to a crore. Generic title-case state titles ("Server Error") became plain sentences.

## Review pass (1 October 2026)

- Hindi readers saw English facts on cards and details (area, floor, age, distance) and an English
  "Unknown Location". The facts now come from the message catalogue; an unknown address is hidden.
- The Explore radius read `10.0 km`; it now reads `10 km`.
- A home with no known type read a lowercase "property" on cards and details; it now reads
  "Property" (one type-to-key map instead of two).
- The 840 px two-pane layout had no golden (the tablet goldens are 834 px, below the break).
  It was rendered at 1280 × 800 in both themes and checked by eye: rail, list, detail pane and
  the "Pick a home" scene. No fault was found apart from the type label above.
- The onboarding diorama baked 25 images; it now bakes 11 (same pixels, less memory). The onboarding
  goldens changed by 0.2 to 2.2 % at layer edges and were checked by eye.

## Web pass (1 October 2026)

- Sign-in at 834 and 1280 px cut the kite and the moon at the top edge: the scene filled the
  strip from its base, so wider screens lost more sky. A cover crop now keeps scene row 125;
  the city base runs on behind the form sheet. The onboarding diorama had the same cut at
  1280 × 800 and uses the same rule.
- The focused field had a teal border and a gold label and cursor. Material's `primary` is
  now teal, so every chosen state has one colour, and the cursor is 3:1 or better.

## Third pass: paper city on every screen (1 October 2026)

The user said the app looked dull. Onboarding carried the diorama; every screen after it was a white list on white. This pass checked every point of the design law again against the final goldens (390 px en, 320 px hi 2×, 834 px, light and dark) and throwaway renders of Tools, the EMI receipt, Help and Assistant.

Found and fixed during the check:
- Header titles that wrap, and titles at 2× text or under 360 px, sat over the towers. The header now keeps a strip of sky for the title and grows the band so the scene stays readable (`scene_header_sliver.dart`; `profile_content_*_320_hi_2x`, `saved_*_320_hi_2x`).
- Saved at 834 px left the right half of the sheet empty. Rows now pair up in two aligned columns from 600 px (`saved_content_*_834_en_1x`).
- Reschedule on a visit pass was a white button on a white sheet and read as plain text. It is now mint card stock like the date stub (`visits_content_*`).
- The Discover lawn stopped in a hard line above the nav roofline. The Discover tab now lets its city run on behind the roofline (`dashboard_view.dart`, `extendBody`).
- Press colours on rows placed straight on a white sheet were hidden under the sheet. Those rows now carry their own transparent ink layer.
- Folder tabs gave screen readers no tap action, and the chosen tab ignored taps. Both fixed (`folder_tabs.dart`).
- The web loader was an orange-to-red gradient with a frosted tile (`web/index.html`). It is now the page tone with the bare logo mark, with dark and reduced-motion variants.
- The native splash was white / old night; it now matches the first frame (`#DDEFE9` / `#0F2826`).

Found on the simulator and the web build, and fixed:
- The sign-in sheet met the city in a dead-straight line: a scroll view paints earlier slivers over later ones, so the lip drawn by the form sliver sat under the skyline. The lip now belongs to the header (`auth_premium_shell.dart`).
- On a phone the status bar pushed the "360 Ghar" wordmark into the kite and the sun. The wordmark now has its own row of sky; the city starts below it.
- At large Hindi text the fixed-height Google and Continue buttons shaved the vowel signs above and below the label. Both use a height floor now; so does the account-delete button.
- The busy Continue spinner was teal on the disabled fill (2.6:1 at night); it is ink now.
- Specs prices had no digit grouping (`₹18648000`); they use Indian grouping (`₹1,86,48,000`).
- A refused Street View image left an empty print; the tile falls back to the listing photo.
- A 1 px line of photo showed under the selected section tab; the header's last pixel row is now the sheet.
- At 390 px the fourth section tab was sliced by the screen edge. The English labels are now About, Media, Specs, Map and fit; narrow screens and large text scroll the strip (`property_details_section_nav_test.dart`).
- The 1280 px details layout had a 16 px left margin and a 61 px right margin; both panes are now centred as one group.
- The web page had no background of its own, and the manifest still had the template blue and copy.

- The Sign in with Apple label was cut at accessibility text sizes (fixed 52 px button); the button now grows with the text size, and its label is translated.

Not fixed, with reason:
- The launch screen on the iOS 27 simulator shows the sky a little shifted (`#D9F0E9` for `#DDEFE9`, `#042926` for `#0F2826`). The launch assets hold the exact values. The same shift appeared with an sRGB-tagged image and with a named sRGB colour, so it comes from the simulator's launch snapshot. Check on a device.
- A 1-device-pixel line (1.07:1) under the section tabs on the web build at fractional pixel ratios; visible only when zoomed.
- A blur band under the iOS status bar on the sign-in screen: an iOS 27 scroll-edge effect, not app paint.
- Highlights that read `slug`, `facing`, `society_name` on one listing: the backend returns field names as the data. Reported for the backend; hiding words by a naming guess would also hide real one-word features.
- Unselected folder tabs at night read by tone and a faint edge only; their text passes AA.
- The MapLibre street style keeps its own colours.

Checked and kept:
- Initial-letter avatar on a flat mint disc in Profile: a stand-in until the user adds a photo; no gradient.
- The Years/Months control in the EMI calculator stays a two-part toggle: it is a real choice, not metadata.
