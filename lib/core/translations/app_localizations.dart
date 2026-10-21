import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:ghar360/core/translations/app_messages.dart';

/// Flutter-owned localization. Data services return failure codes, not UI text.
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en', 'US'), Locale('hi', 'IN')];
  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      AppLocalizations(Localizations.maybeLocaleOf(context) ?? supportedLocales.first);

  String text(String key, {Map<String, String> params = const {}}) {
    final messages = appMessages[locale.languageCode == 'hi' ? 'hi_IN' : 'en_US']!;
    final template = messages[key] ?? appMessages['en_US']![key] ?? key;
    // Replace in one pass: a parameter value must never be interpreted as another
    // placeholder. Support both forms found in the existing bilingual catalog.
    return template.replaceAllMapped(RegExp(r'@([a-zA-Z0-9_]+)|\{([a-zA-Z0-9_]+)\}'), (match) {
      return params[match.group(1) ?? match.group(2)] ?? match.group(0)!;
    });
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
