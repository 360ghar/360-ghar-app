import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/controllers/localization_controller.dart';
import 'package:ghar360/core/controllers/theme_controller.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/profile/presentation/controllers/preferences_controller.dart';
import 'package:ghar360/features/profile/presentation/widgets/profile_sheet_page.dart';

/// Notifications, theme and language. Every control saves when it changes;
/// there is no separate Save button.
class PreferencesView extends StatelessWidget {
  const PreferencesView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ProfileSheetPage(
      title: l10n.text('my_preferences'),
      identifier: 'qa.profile.preferences.screen',
      children: [
        SheetSectionTitle(l10n.text('notifications'), top: 4),
        const _NotificationSwitches(),
        SheetSectionTitle(l10n.text('display_preferences')),
        const _ThemeSetting(),
        SheetSectionTitle(l10n.text('language_preferences')),
        const _LanguageSetting(),
      ],
    );
  }
}

/// Switches backed by `/users/notification-settings`. A failed write puts the
/// switch back and says so under it.
class _NotificationSwitches extends ConsumerWidget {
  const _NotificationSwitches();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationSettingsProvider);
    final controller = ref.read(notificationSettingsProvider.notifier);
    final l10n = context.l10n;
    if (state.settings == null && state.loading) {
      return const _SwitchSkeleton();
    }
    if (state.settings == null) {
      return ErrorStates.inlineError(
        message: l10n.text('notification_settings_load_error'),
        onRetry: controller.load,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final key in state.toggles)
          SwitchListTile.adaptive(
            key: ValueKey('qa.profile.preferences.$key'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.text(key)),
            subtitle: Text(
              l10n.text('${key}_desc'),
              style: TextStyle(color: context.design.textSecondary),
            ),
            value: state.valueOf(key),
            onChanged: state.savingKey != null ? null : (value) => controller.toggle(key, value),
          ),
        if (state.saveError != null)
          ErrorStates.inlineError(message: l10n.text('notification_settings_save_error')),
      ],
    );
  }
}

class _SwitchSkeleton extends StatelessWidget {
  const _SwitchSkeleton();
  @override
  Widget build(BuildContext context) => Skeleton(
    child: Column(
      children: [
        for (var i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(height: 16, width: 160),
                      SizedBox(height: 8),
                      SkeletonBox(height: 12, width: 220),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                SkeletonBox(width: 48, height: 28, radius: 14),
              ],
            ),
          ),
      ],
    ),
  );
}

class _ThemeSetting extends ConsumerWidget {
  const _ThemeSetting();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (nameKey, saving, failed) = ref.watch(
      themeProvider.select((s) => (s.nameKey, s.persistence.isLoading, s.persistence.hasError)),
    );
    return _Setting(
      title: context.l10n.text('app_theme'),
      description: context.l10n.text('app_theme_desc'),
      identifier: 'qa.profile.preferences.theme_selector',
      icon: KnifeIcon.moon,
      value: context.l10n.text(nameKey),
      saving: saving,
      failed: failed,
      onPressed: () => _chooseTheme(context, ref),
      onRetry: () => ref.read(themeProvider.notifier).retry(),
    );
  }

  Future<void> _chooseTheme(BuildContext context, WidgetRef ref) async {
    final selected = ref.read(themeProvider).mode;
    final result = await showDialog<AppThemeMode>(
      context: context,
      builder: (dialogContext) => _ChoiceDialog(
        title: dialogContext.l10n.text('app_theme'),
        choices: {
          for (final mode in AppThemeMode.values)
            mode: dialogContext.l10n.text('${mode.name}_mode'),
        },
        selected: selected,
      ),
    );
    if (result != null && context.mounted) {
      await ref.read(themeProvider.notifier).setThemeMode(result);
    }
  }
}

class _LanguageSetting extends ConsumerWidget {
  const _LanguageSetting();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (name, saving, failed) = ref.watch(
      localizationProvider.select(
        (s) => (s.languageName, s.persistence.isLoading, s.persistence.hasError),
      ),
    );
    return _Setting(
      title: context.l10n.text('select_language'),
      description: context.l10n.text('select_language_desc'),
      identifier: 'qa.profile.preferences.language_selector',
      icon: KnifeIcon.compass,
      value: name,
      saving: saving,
      failed: failed,
      onPressed: () => _chooseLanguage(context, ref),
      onRetry: () => ref.read(localizationProvider.notifier).retry(),
    );
  }

  Future<void> _chooseLanguage(BuildContext context, WidgetRef ref) async {
    final selected = ref.read(localizationProvider).locale;
    final result = await showDialog<Locale>(
      context: context,
      builder: (dialogContext) => _ChoiceDialog(
        title: dialogContext.l10n.text('select_language'),
        choices: {
          for (final locale in AppLocalizations.supportedLocales)
            locale: locale.languageCode == 'hi' ? 'हिंदी' : 'English',
        },
        selected: selected,
      ),
    );
    if (result != null && context.mounted) {
      await ref
          .read(localizationProvider.notifier)
          .changeLanguage(result.languageCode, result.countryCode ?? '');
    }
  }
}

/// A setting row: title and one line, then the current value as a tonal
/// button that opens the choices. A failed save stays under it with retry.
class _Setting extends StatelessWidget {
  const _Setting({
    required this.title,
    required this.description,
    required this.identifier,
    required this.icon,
    required this.value,
    required this.saving,
    required this.failed,
    required this.onPressed,
    required this.onRetry,
  });
  final String title;
  final String description;
  final String identifier;
  final KnifeIcon icon;
  final String value;
  final bool saving;
  final bool failed;
  final VoidCallback onPressed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.titleSmall),
        const SizedBox(height: 2),
        Text(description, style: text.bodyMedium?.copyWith(color: context.design.textSecondary)),
        const SizedBox(height: 12),
        Semantics(
          identifier: identifier,
          child: OutlinedButton.icon(
            key: ValueKey(identifier),
            onPressed: saving ? null : onPressed,
            icon: saving ? LoadingStates.buttonSpinner() : PaperIcon(icon, size: 20),
            label: Text(value),
          ),
        ),
        if (failed)
          ErrorStates.inlineError(
            message: context.l10n.text('preferences_save_error'),
            onRetry: onRetry,
          ),
      ],
    );
  }
}

/// Theme and language choices. The dialog shape comes from the theme.
class _ChoiceDialog<T> extends StatelessWidget {
  const _ChoiceDialog({required this.title, required this.choices, required this.selected});
  final String title;
  final Map<T, String> choices;
  final T selected;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final MapEntry(:key, :value) in choices.entries)
            ListTile(
              title: Text(value),
              trailing: key == selected
                  ? PaperIcon(KnifeIcon.check, color: context.design.textPrimary)
                  : null,
              onTap: () => Navigator.of(context).pop(key),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.text('cancel')),
      ),
    ],
  );
}
