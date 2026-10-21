# Design system: Paper Cut Diorama

The app is a street in Gurugram made of cut card stock. Layers sit at different depths. One light comes from the top left, so every shadow is short and falls to the bottom right. A shadow takes the tint of the surface below it. There is no glow and no wide blurred shadow.

Scenes, sheets, dialogs, the navigation strip and state vignettes use hand-cut edges and grain. Every screen sits on one page tone, the onboarding sky. Content sits on white card-stock sheets that rise over a scene header. Dense screens (lists, property facts, forms, visits, calculators) sit flat on those white sheets, so they stay easy to scan; they do not sit flat on the page.

The logic comes from the website (`360ghar-web-ui-2/docs/design-system.md`). The app does not use the website's orange palette or its Sentient font.

## Files

| Part | Path | Notes |
| --- | --- | --- |
| Tokens | `lib/core/design/app_design_tokens.dart` | Marigold ramp, neem ink, teal, mint, brick, night paper, status. |
| Palette | `lib/core/design/app_design_extensions.dart` | `context.design` returns `AppPalette` for the current brightness. |
| Theme | `lib/core/design/app_design_theme.dart`, `app_design_components.dart` | Type, app bar, buttons, fields, list rows, expanding rows, dialogs, sheets, page transitions. |
| Page transition | `lib/core/design/paper_page_transition.dart` | `PaperSlideTransitionsBuilder` (Android, web on non-Apple devices, desktop). |
| Cut edges | `lib/core/design/paper/paper_cut.dart` | Port of the website `cut.ts`: seeded RNG, `cutPolygon`, `cutBandPath`, `rooflineBandPath`, `zigzagEdge`, path parser. |
| Chrome | `lib/core/design/paper/paper_chrome.dart` | `paperShadows`, `CutBorder`, `ReceiptBorder` (torn zigzag foot). |
| Paper art | `lib/core/design/paper/paper_art.dart` | Layer model, painter, night windows, `litCount` (lights the first N windows of a `counted` layer), grain. |
| Scene data | `lib/core/design/paper/paper_scene_data.dart` | Generated. Diorama, state scenes, `paperHeaders` (saved, visits, profile, assistant, skyline) and `paperVignettes` (calculator, key, document, tower, home, plot, pg). |
| Icons | `lib/core/design/paper/knife_icons.dart` | Generated. 88 knife-cut icons (85 from the website, plus `eyeOff`, `stop`, `kite`). |
| Widgets | `lib/core/widgets/paper/` | `PaperIcon`, `PaperSheet`, `PaperVignette`, `PaperStrip`, `BakedPaperScene`, `PaperScrollPage`, `SceneHeaderSliver`, `FolderTabs`, `SheetSliver`, `PaperSheetBody`, `PaperLip`, `CountUpText`, `PaperArtView`, `PaperSkylineStrip`, `SkylineBackdrop`. |
| Listing print | `lib/core/widgets/common/property_list_card.dart` | Tile (Explore strip) and row (Saved). |
| Skeletons | `lib/core/widgets/common/loading_states.dart` | `LoadingStates.*`, `Skeleton`, `SkeletonBox`, `SkeletonSheet`. |
| Shell | `lib/core/routes/app_pages.dart` | `heroSafeBranchContainer`: branch container with `HeroMode`. |
| Generator | `tool/paper/` | Vendored website TypeScript, `headers.ts` (header scenes, 960 × 260), `vignettes.ts` (ported web vignettes) and `generate.ts`. |

## Palette

Three hues, three jobs. **Marigold** `#F5B400` is the one action (owner's choice). **Peacock teal** marks what is chosen or tappable: icons, links, the selected tab, switches, focus rings, progress. **Brick** is the saved heart. Everything else is neem ink (a green-black, never brown) on white card stock over the mint-haze sky by day, and green-black card stock under a deep teal sky at night. There is no cream, no beige, no UI-kit gray and no blue slate.

| Token | Day | Night | Use |
| --- | --- | --- | --- |
| `background` | `#DDEFE9` | `#0F2826` | The page on every screen: the onboarding sky. Equals `tone(PaperTone.sky)`, so a scene header meets the page with no seam. Also the app bar and the compact header. |
| `surface`, `cardBackground` | `#FFFFFF` | `#1C2F2B` | Sheets on the page: list and form bodies, cards, the navigation strip, dialogs, bottom sheets. |
| `raised`, `inputBackground` | `#FFFFFF` | `#22372F` | Fields and pressed rows on a sheet. |
| `sheetLip` | `#DCE4E1` | `#2E403C` | The top edge of a sheet. At night a 1 px lighter lip of the sheet's own colour, where the light catches the cut. |
| `tabBehind` | `#EEF7F4` | `#162C28` | An unselected folder tab: the sheet mixed halfway toward the page, card stock behind the selected tab. |
| `textPrimary` | `#182320` | `#EDF3F0` | Body and headings. |
| `textSecondary` | `#4B5955` | `#B6C5C0` | Supporting text. |
| `textTertiary` | `#5C6A66` | `#8FA29C` | Hints, captions. |
| `accent` | `#0C6A61` | `#5CC4B6` | Icons, links, selected tab and nav item, switches, focus ring, progress. Never a large fill. |
| `slip` | `#E6F2EE` | `#24423B` | Mint fill under a selected row or tab, and the quiet second button. Text on it stays ink. |
| `notice` | `#FFF4D1` | `#2A2616` | Amber note over kept content (a failed refresh). Text on it stays ink. |
| `favoriteActive` | `#B03E22` | `#F08A64` | The saved heart. |
| `border` | `#DCE4E1` | `#2B3B37` | Decorative edges only. |
| `fieldBorder` | `#73837F` | `#7A8D87` | Field outlines (3:1 on the page, the sheet and the field). |
| `buttonPrimary` | `#F5B400` | `#F5B400` | The one primary action. Label `#182320` (8.8:1). |
| `error`, `success`, `warning` | `#B42318`, `#1D7443`, `#8A5A00` | `#FF8A7A`, `#6FCF97`, `#FFC934` | Status text and icons. |

Material's `colorScheme.primary` is the teal `accent`, not gold. Material paints chosen
states with it: the text cursor, a focused field label, sliders, checkboxes, radios and
date pickers. Gold on white is 1.8:1, below the 3:1 a control needs. The action buttons
set gold themselves.

### Contrast

`test/core/design/app_design_theme_test.dart` checks every text pair in both themes on the page, the sheet, the field and the unselected tab. Text needs 4.5:1; field borders, focus rings and the caution icon need 3:1. Text on a slip stays ink (primary or secondary).

| Day | page `#DDEFE9` | sheet `#FFFFFF` | tab behind `#EEF7F4` | mint slip `#E6F2EE` | amber notice `#FFF4D1` |
| --- | ---: | ---: | ---: | ---: | ---: |
| textPrimary `#182320` | 13.5 | 16.2 | 14.8 | 14.1 | 14.7 |
| textSecondary `#4B5955` | 6.2 | 7.3 | 6.7 | 6.4 | 6.7 |
| textTertiary `#5C6A66` | 4.8 | 5.7 | 5.2 | 4.9 | 5.2 |
| accent `#0C6A61` | 5.4 | 6.5 | 5.9 | 5.6 | 5.9 |
| favoriteActive `#B03E22` | 5.0 | 5.9 | 5.4 | 5.1 | 5.4 |
| error `#B42318` | 5.5 | 6.6 | 6.0 | 5.7 | 6.0 |
| success `#1D7443` | 4.9 | 5.8 | 5.3 | 5.0 | 5.3 |
| warning `#8A5A00` | 5.0 | 5.9 | 5.4 | 5.2 | 5.4 |
| fieldBorder `#73837F` | 3.3 | 4.0 | 3.6 | 3.5 | 3.6 |

| Night | page `#0F2826` | sheet `#1C2F2B` | raised `#22372F` | tab behind `#162C28` | mint slip `#24423B` |
| --- | ---: | ---: | ---: | ---: | ---: |
| textPrimary `#EDF3F0` | 13.8 | 12.5 | 11.3 | 13.1 | 9.7 |
| textSecondary `#B6C5C0` | 8.7 | 7.9 | 7.1 | 8.2 | 6.1 |
| textTertiary `#8FA29C` | 5.8 | 5.2 | 4.7 | 5.5 | 4.1 |
| accent `#5CC4B6` | 7.4 | 6.7 | 6.1 | 7.0 | 5.2 |
| favoriteActive `#F08A64` | 6.3 | 5.7 | 5.2 | 6.0 | 4.5 |
| error `#FF8A7A` | 6.8 | 6.2 | 5.5 | 6.4 | 4.8 |
| success `#6FCF97` | 8.2 | 7.4 | 6.7 | 7.8 | 5.8 |
| warning `#FFC934` | 10.1 | 9.2 | 8.3 | 9.6 | 7.1 |
| fieldBorder `#7A8D87` | 4.4 | 4.0 | 3.6 | 4.2 | 3.1 |

The old day field border `#839390` failed on the sky (2.7:1), so it moved to `#73837F`.

Label `#182320` on marigold `#F5B400`: 8.8:1.

## Surfaces

One page tone, white sheets:

- The page is the sky (`background`) on every screen, with grain. There is no tone per tab and no white page. The app bar, the compact scene header and the scaffold are the page tone; an app bar never tints or lifts when a list scrolls under it.
- Content sits on card-stock sheets (`surface`): white by day, `#1C2F2B` at night with a 1 px `sheetLip` along the top. A sheet has a hand-cut top edge where it meets the page or a scene.
- Dense content (lists, facts, forms, visits, calculator inputs, settings rows) sits flat on a sheet: no box per row, no rules between rows; spacing and type weight rank the information.
- A sheet on the page casts `paperShadows(elevation, design.shadowOn(design.background))`. Something on a sheet uses `shadowOn(design.surface)`. Never use `background` as a card or sheet fill.
- Fields on a sheet are `raised` with a `fieldBorder` outline. List rows use `ListTileTheme` (16 px sides, bare teal icon, bold 16 px title, secondary subtitle); expanding rows use `ExpansionTileTheme` with no rule open or closed.

## System pieces

| Piece | Where | What it is |
| --- | --- | --- |
| `PaperScrollPage` | `lib/core/widgets/paper/` | A `CustomScrollView` on the page tone. A pinned `SceneHeaderSliver` on top; the slivers sit on the white sheet body below it. |
| `SceneHeaderSliver` | `lib/core/widgets/paper/` | Pinned header. Paints the sky and grain, the scene layers (baked once, moved by scroll: deeper layers move less), the title in Erode (always visible, it moves from the foot of the scene into the compact bar), actions on the right, and the sheet's cut lip at its foot. Compact height: safe top + 56. Scene band: up to 148 px, smaller at 320 px width or 2x text. |
| `FolderTabs` | `lib/core/widgets/paper/` | Index tabs cut into the top edge of the sheet. The selected tab is the sheet colour, weight 800, primary text; the others sit behind in `tabBehind` with secondary text. The selected shape slides in 250 ms. Labels may wrap to two lines. |
| `SheetSliver` | `lib/core/widgets/paper/` | The white sheet body under the header lip. |
| `BakedPaperScene` | `lib/core/widgets/paper/` | The diorama's bake-to-image and `Flow` code: a scene from `PaperArtData` and layer groups, moved by a `ValueListenable<double>`. |
| `CountUpText` | `lib/core/widgets/paper/` | A number that counts from the previous value to the new one. The first frame shows the final value; it snaps under reduced motion. |
| Roofline nav | `lib/core/widgets/navigation/bottom_nav_bar.dart` | The strip's top edge is a low Gurugram roofline (flat roofs, water tanks, a stair room). One taller tower with a rooftop tank and one window stands above the active tab and slides to it. Day: the window is a cut hole; night: lit gold. The active tab also has the teal icon and a bold label. No dot, no pill. |
| Listing print | `lib/core/widgets/common/property_list_card.dart` | Tile (Explore strip): the photo is a print with a hand-cut edge (`CutBorder`, amp 1.5); a white label with a cut top edge lies 18 px over the photo's foot and carries the price in Erode, the title, one facts line and the place. Row (Saved): a 104 x 88 print beside the same words. The heart is bare on the label (ink, or solid brick when saved). A selected tile turns its label into a mint slip; a selected row lays a slip under the row. The photo is a `Hero` with the tag `propertyPhotoHeroTag(id)`. |
| Visit pass | `lib/features/visits/` | Each visit is a ticket: a stub with a tear-off date (the day in large Erode), a column of punched holes that show the page, then the body. Status stays text colour. The relationship manager is a visiting card. |
| Receipt | `ReceiptBorder` in `lib/core/design/paper/paper_chrome.dart` | Calculator results on a sheet with a torn zigzag foot. |
| Skeletons | `lib/core/widgets/common/loading_states.dart` | Blocks in the page tone on a white sheet by day; a light step (the sheet plus 6% white) at night; a lighter sheen. Each skeleton brings its own sheet, so it reads on the page. Shapes follow the real layouts: the deck card with its label cut over the photo and two deck edges behind; list rows as a print and three lines; visit passes as a stub, holes and a body. |

### Scene tones

The scenes are cut from coloured card stock, one colour per element, drawn from the city: a mint haze sky, a marigold sun, white clouds, hazy teal Cyber City towers, sandstone sector blocks, green lawns and neem trees, terracotta and brick, teal sign boards, a sindoor map pin, flame-red gulmohar blooms and a green CNG auto on the onboarding street. At night the same papers sit under a deep teal sky, the sun is a cream moon, and the windows of the towers and blocks light up as flat gold. A lit window is a flat fill, not a glow.

| Tone | Day | Night | Where |
| --- | --- | --- | --- |
| `bg`, `sky` | `#DDEFE9` | `#0F2826` | Vignette card, onboarding and auth sky |
| `sun` | `#F5B400` | `#F2E6C4` | Sun, moon |
| `cloud` | `#FFFFFF` | `#1D3A37` | Clouds |
| `far` | `#A9D0C6` | `#1A3935` | Far towers |
| `mid` | `#F1C48D` | `#4E3B2C` | Sector blocks |
| `main` | `#E27A4E` | `#6B3A26` | The subject: hanging sign, rooftop, umbrella |
| `deep` | `#26302D` | `#070A09` | Poles, wires, digits, water tank, lamps |
| `near` | `#2F6B55` | `#0E2520` | Near ground |
| `kerb` | `#3A413E` | `#080B0A` | Road |
| `accent` | `#F5B400` | `#E0A200` | Kite, crane, metro train, milestone cap |
| `highlight` | `#FFFFFF` | `#E8E1CC` | Milestone, dish, road marks |
| `pin` | `#D6452C` | `#E4573C` | Map pins (scenes and the mini map) |
| `home`, `lit` | `#FFFFFF`, `#FFD24D` | `#2B3431`, `#FFC934` | The home, lit windows |
| `grass`, `tree` | `#8CC279`, `#3E8A5F` | `#1F4A33`, `#153A2B` | Lawns and tufts, foliage and vegetables |
| `sign` | `#1F7A70` | `#1F5A53` | Sign boards, the chai-stall awning |
| `pavement` | `#D9CDB8` | `#2E2A22` | Pavement, building site, lane |
| `shop`, `bloom` | `#C9623A`, `#E4572E` | `#5A2E1E`, `#7A2A1A` | Shop row; gulmohar canopy, traffic cone, barricade |
| `trunk`, `auto`, `cow`, `concrete` | `#6B4631`, `#2F8F4E`, `#F4EFE6`, `#D5DBD7` | `#2A1B12`, `#1E5A35`, `#BFB8A8`, `#2A3431` | Trunks and cart, CNG auto, cow, metro viaduct and concrete frame |

## Type

| Role | Face | Notes |
| --- | --- | --- |
| Display, headings, prices, big numbers | **Erode** 400–700 | Indian Type Foundry, Fontshare. A warm, low-contrast serif. Has ₹ (U+20B9) and lining figures. Hindi falls back to **Noto Serif Devanagari**, which matches its stroke weight and serifs. |
| Body, labels, buttons, fields | Manrope (variable) | Neutral workhorse. Text buttons are ink in both themes, weight 700; links inside notes are teal; marigold is for the one filled action. |
| Hindi | Noto Serif Devanagari (display), Noto Sans Devanagari (body) | Each face has its own matching fallback. |

- Erode replaced Quilon on 1 October 2026: Quilon's wide, poster-like shapes made headings and prices look clumsy, and its sans Hindi fallback did not match it. Erode was picked from 14 Fontshare faces with ₹, rendered with real app content (prices, card titles, state headings, Hindi). Its print-like warmth suits paper craft and reads well at card sizes; it suits rentals and PGs as well as purchases.
- Licence: ITF Free Font License (`assets/fonts/erode/FFL.txt`). It allows use in apps and self-hosting. It forbids modified files, so the TTFs ship unmodified and are not subset. `assets/fonts/sources.json` records source and SHA-256.
- Display styles use line height 1.25, so Devanagari matras do not clip, and no negative tracking.
- Prices are compact and trimmed: `₹85 L`, `₹1.25 Cr`, `₹43,400` (`IndianCurrency.compact`).
- Property facts come from `lib/core/presentation/property_labels.dart`, never from the model:
  area (`1,450 sq ft`, en_IN grouping), floor, age and distance, each from the message catalogue
  in English and Hindi. An unknown address is hidden, not shown as a placeholder.
- Keep a display line to two lines or fewer.

## Shadows and depth

`paperShadows(elevation, tint)` returns a contact shadow plus one drop with negative spread. The tint is `context.design.shadowOn(surfaceBelow)`: a darker shade of the surface below, never black.

| Elevation | Contact | Drop |
| --- | --- | --- |
| `flat` | none | none |
| `low` | (0.5, 1) blur 1, 6% | (1.5, 3) blur 6, spread −3, 14% |
| `mid` | same | (3, 6) blur 14, spread −6, 16% |
| `high` | same | (4, 10) blur 20, spread −8, 18% |

Paper art uses one shadow per layer group: the union of the layer's paths, offset down and right and blurred (vignettes (2, 3) σ 1.1; diorama (3, 4) σ 1.6 in scene units). Window holes show the shadow of the wall above them.

## Hand-cut edges

- `CutBorder(seed: 'dialog')` gives a sheet outline cut from a seed. The same seed gives the same edge on every rebuild and on every platform.
- Every cut point sits at most `amp` pixels (default 2) inside the rect. Pad content by more than `amp` on every side ("clear the cut"). `PaperSheet` asserts this.
- `CutBorder` paints its own shadow outside the shape. Content is never clipped with a `ClipPath`.
- `cutBandPath` gives the cut top edge of a full-width strip (navigation bar).
- Use one seed per place, so two screens never show the same edge.

## Grain

A 160 × 160 tile of seeded film grain (`paperGrainTile`) built once with `Picture.toImageSync`, tiled with an `ImageShader`. Colour: neem ink at about 4% by day, mint light at about 6% at night. Grain goes on the page and scene backgrounds only (the sky page, scene headers, vignette cards, onboarding, auth). Text, icons, controls and sheets stay crisp above it.

## Icons

- 85 knife-cut icons from the website plus three app icons (`eyeOff`, `stop`, `kite`) in `KnifeIcon`, drawn by `PaperIcon`: solid polygons on a 24 × 24 grid, even-odd fill, no strokes, circles as octagons.
- Like `Icon`, `PaperIcon` takes its size and colour from `IconTheme`, and a parent that forces a larger box (a field's prefix slot) centres the mark; it never stretches it.
- Icons are bare. Never put a tile, chip or circle behind an icon.
- Give icon buttons a `semanticLabel` or a `Tooltip`.
- The Google sign-in button keeps the official multi-colour mark.
- `kite` is the Assistant mark (the onboarding kite). Use it wherever the meaning is "Assistant".

## State scenes

`PaperVignette(PaperScene.empty, seed: 'liked')`. Each scene is a print on a hand-cut card (edge amp 2.6 in scene units) that lies on the page with the tight `low` paper shadow. Over a live map the state takes the list sheet's place instead of covering the map. Scenes: `empty` ("khali plot"), `error` ("tuta board"), `offline` ("kati patang"), `notFound` ("Sector 404"), `location` (a pin over a home). Each screen has its own seed; the list is `SCENE_SEEDS` in `tool/paper/generate.ts`.

## Motion

- Content is visible without animation. Never start content at opacity 0.
- With `MediaQuery.disableAnimations`, nothing moves.
- Buttons change colour on hover and press; they never move or scale.
- Page transitions: iOS and macOS keep the Cupertino slide and its back swipe. Android, web on non-Apple devices, Windows, Linux and Fuchsia use `PaperSlideTransitionsBuilder`: the new page slides in from the trailing edge over the old one, the old page shifts a quarter to the leading edge, and nothing fades. The new page casts the `mid` paper shadow from its leading edge only. On the web, Flutter reads the platform from the browser.
- The listing photo flies to the details gallery as a `Hero` (`property-photo-<id>`). The shell wraps each branch in `HeroMode`, enabled only for the open tab, so a photo shown in two tabs never clashes. A screen that shows the same home twice in one tab (a list beside a details pane) must turn one hero off with `HeroMode(enabled: false)`.
- The Discover deck: the next card settles from 0.93 to 1 and a swiped card leaves in 400 ms; with reduced motion both are instant.

## Regenerate paper data

```sh
node --experimental-strip-types tool/paper/generate.ts
flutter test test/core/design/paper/
```

The generator writes `paper_scene_data.dart` (diorama, state scenes, `paperHeaders`, `paperVignettes`), `knife_icons.dart` and `test/fixtures/paper_fixtures.json`, then formats the Dart files. The fixture test proves the Dart cut functions match the TypeScript output exactly.
