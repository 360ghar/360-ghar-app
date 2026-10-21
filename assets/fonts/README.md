# Bundled app fonts

| Family | Use | Source | Licence |
| --- | --- | --- | --- |
| Erode (400, 500, 600, 700) | Display, headings, prices, big numbers | [Fontshare](https://www.fontshare.com/fonts/erode), Indian Type Foundry | ITF Free Font License (`erode/FFL.txt`) |
| Manrope (variable, weight 200–800) | Body, labels, buttons | [Google Fonts repository](https://github.com/google/fonts/tree/23e54b51ddffbc7713c583748e3bd86f62b1fa4a/ofl) at `23e54b51` | OFL (`manrope/OFL.txt`) |
| Noto Serif Devanagari (variable) | Hindi fallback for the display face | Google Fonts repository at `23e54b51` (same bytes as `main` on 1 October 2026) | OFL (`notoserifdevanagari/OFL.txt`) |
| Noto Sans Devanagari (variable) | Hindi fallback for the body face | Google Fonts repository at `23e54b51` | OFL (`notosansdevanagari/OFL.txt`) |

All files are unchanged from their source. The ITF licence forbids modified or subset font files, so do not subset Erode. `sources.json` records the source, size and SHA-256 of each file.

`AppDesignTheme` selects these local families. There is no runtime font download. `test/helpers/load_app_fonts.dart` loads the same bytes for golden and workload tests.
