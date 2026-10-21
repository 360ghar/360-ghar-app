# HEAD baseline native build

> Evidence note: screenshots, native XML captures and JSON observations cited here are scratch artifacts kept on the verification machine. They are not committed (see `.gitignore`), so links to them do not resolve in a clone.

Source: `aa839932e85752755a11aa5de33970327cb226c9`, extracted with `git archive HEAD`.

This is a separate build tree. It does not contain the migrated product source.
PhoneEntryView and AuthPremiumShell remain byte-identical to HEAD. The earlier
preinstalled-app screenshot is not a verified HEAD baseline.

## Configuration isolation

Environment files and generated production Firebase configuration were excluded.
The empty development configuration, localhost Dart defines, and synthetic iOS
Firebase plist were copied from `/tmp/360ghar-final-native` only. Generated Dart
Firebase constants were replaced with values from that same synthetic plist.
Firebase is disabled. API and auth endpoints are `http://127.0.0.1:54321`.
No production .env or credentials were copied.

## Build environment and compatibility

Flutter 3.47.4, Dart 3.13.3; HEAD's own iOS project and Swift Package Manager setup.
`flutter pub get` aligned SDK pins for intl (0.20.3), matcher (0.12.20), meta
(1.19.0), test_api (0.7.12), and vector_math (2.4.3), and added generated directory
analyzer exclusions. `flutter build ios --config-only` removed the obsolete
MinimumOSVersion field from AppFrameworkInfo.plist. The project target remains
15.0. No current native project files have been copied.

## Build commands

```
flutter pub get
flutter build ios --simulator --debug --config-only --no-codesign --no-pub --dart-define-from-file=dart_defines.json
flutter build ios --simulator --debug --no-codesign --no-pub --dart-define-from-file=dart_defines.json
```

Build status: PASSED (exit 0), Xcode compilation 166.6 seconds.
Artifact: `/tmp/360ghar-baseline-native/build/ios/iphonesimulator/Runner.app`.
Final tracked-file comparison confirms all product/UI source remains HEAD; only
the five configuration/build compatibility files listed above differ. The built
app contains the exact synthetic Firebase plist. No app install, launch, driver, or simulator action was
performed by this task. Detailed machine-readable provenance is in
`baseline-provenance.json`.

## Verified native capture

The root task installed this exact build on the dedicated iPhone 17e simulator
(`753B27FC-5A6A-49BF-8BF1-353EA097393E`, iOS 27). A clean app/keychain launch,
onboarding Skip and phone-entry assertion passed in 13 seconds. Evidence:
`/tmp/360ghar-head-before.xml` and `docs/migration/screenshots/phone-entry-before-ios.png`.
The image shows the original automatic input focus and visible keyboard.
The previous image from an unknown preinstalled version has been replaced.
The product source was not edited to alter the captured screen.
