import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/translations/app_translations.dart';

void main() {
  test('contains required translation keys in supported locales', () {
    final keys = AppTranslations().keys;
    const required = <String>[
      'Call',
      'WhatsApp',
      'profile_picture',
      'unavailable',
      'agent_contact_unavailable',
      'could_not_open_phone_dialer',
      'could_not_open_whatsapp',
      'auth_phone_title',
      'auth_phone_subtitle',
      'auth_login_subtitle',
      'auth_signup_personal_subtitle',
      'auth_signup_security_title',
      'auth_signup_security_subtitle',
      'auth_chip_verified',
      'auth_chip_transparent',
      'auth_chip_support',
      'auth_chip_private',
      'auth_chip_secure',
      'onboarding_slide_1_title',
      'onboarding_slide_1_desc',
      'onboarding_slide_2_title',
      'onboarding_slide_2_desc',
      'onboarding_slide_3_title',
      'onboarding_slide_3_desc',
      'skip',
    ];

    for (final locale in ['en_US', 'hi_IN']) {
      final localeMap = keys[locale];
      expect(localeMap, isNotNull, reason: 'Missing locale map for $locale');
      for (final key in required) {
        expect(localeMap!.containsKey(key), isTrue, reason: 'Missing "$key" in $locale');
      }
    }
  });

  test('new translation keys exist in both en_US and hi_IN', () {
    final keys = AppTranslations().keys;
    const newKeys = <String>[
      'take_photo',
      'choose_from_gallery',
      'profile_image_selected',
      'failed_to_pick_image',
      'content_unavailable',
      'failed_to_load_content',
      'failed_to_load_messages',
      'failed_to_delete_conversation',
    ];

    for (final locale in ['en_US', 'hi_IN']) {
      final localeMap = keys[locale];
      expect(localeMap, isNotNull, reason: 'Missing locale map for $locale');
      for (final key in newKeys) {
        expect(localeMap!.containsKey(key), isTrue, reason: 'Missing new key "$key" in $locale');
        expect(
          localeMap[key]!.isNotEmpty,
          isTrue,
          reason: 'Key "$key" in $locale should have a non-empty value',
        );
      }
    }
  });

  // The two tests below are structural rather than a hand-maintained key list.
  // A hand-maintained list only catches keys someone remembered to add to it,
  // which is why 24 auth/onboarding keys silently existed in en_US only, and
  // why 'property_purpose' and 'complete' were rendered to users as raw keys.
  test('en_US and hi_IN define exactly the same keys', () {
    final keys = AppTranslations().keys;
    final en = keys['en_US']!.keys.toSet();
    final hi = keys['hi_IN']!.keys.toSet();

    expect(
      en.difference(hi).toList()..sort(),
      isEmpty,
      reason: 'Defined in en_US but missing from hi_IN, so Hindi falls back to English',
    );
    expect(
      hi.difference(en).toList()..sort(),
      isEmpty,
      reason: 'Defined in hi_IN but missing from en_US, so English users see the raw key',
    );
  });

  test('every translation key referenced in lib/ is defined in both locales', () {
    final keys = AppTranslations().keys;
    final en = keys['en_US']!;
    final hi = keys['hi_IN']!;

    // Matches `'some_key'.tr` and `'some_key'.trParams({...})`. Keys composed
    // at runtime (e.g. 'doc_$id') are not literals and are correctly skipped.
    final pattern = RegExp(r"'([a-z0-9_]+)'\s*\.tr(Params)?\b");
    final referenced = <String, String>{};

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final match in pattern.allMatches(entity.readAsStringSync())) {
        referenced.putIfAbsent(match.group(1)!, () => entity.path);
      }
    }

    expect(referenced, isNotEmpty, reason: 'Scanner found no keys; the regex is broken');

    final undefined = <String>[];
    referenced.forEach((key, path) {
      if (!en.containsKey(key)) undefined.add('$key (en_US) used in $path');
      if (!hi.containsKey(key)) undefined.add('$key (hi_IN) used in $path');
    });

    expect(
      undefined..sort(),
      isEmpty,
      reason: 'GetX renders the key itself when a lookup misses, so these show as raw text',
    );
  });
}
