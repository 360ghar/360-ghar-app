import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/profile/presentation/widgets/profile_sheet_page.dart';
import 'package:package_info_plus/package_info_plus.dart';

final packageVersionProvider = FutureProvider<PackageInfo?>((ref) async {
  try {
    return await PackageInfo.fromPlatform();
  } catch (_) {
    return null;
  }
});

class AboutView extends ConsumerWidget {
  const AboutView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageVersionProvider).value;
    final l10n = context.l10n;
    final design = context.design;
    final text = Theme.of(context).textTheme;
    Widget section(String key) => SheetSectionTitle(l10n.text(key));
    return ProfileSheetPage(
      title: l10n.text('about_360ghar'),
      identifier: 'qa.profile.about.screen',
      children: [
        Row(
          children: [
            Image.asset(
              design.isDark ? 'assets/icons/logo_mark_dark.png' : 'assets/icons/logo_mark.png',
              width: 64,
              height: 64,
              semanticLabel: '360ghar',
              errorBuilder: (_, _, _) => const SizedBox.square(dimension: 64),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('360ghar', style: text.headlineMedium),
                  Text(
                    l10n.text('about_tagline'),
                    style: text.bodyMedium?.copyWith(color: design.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        section('about_app_section_title'),
        Text(
          l10n.text('about_app_section_body'),
          style: text.bodyLarge?.copyWith(color: design.textPrimary),
        ),
        section('about_key_features_title'),
        for (final (icon, key) in const [
          (KnifeIcon.compare, 'about_feature_swipe'),
          (KnifeIcon.tour, 'about_feature_tours'),
          (KnifeIcon.heartSolid, 'about_feature_favorites'),
          (KnifeIcon.pin, 'about_feature_location'),
          (KnifeIcon.user, 'about_feature_agent'),
        ])
          _feature(
            context,
            icon: icon,
            title: l10n.text('${key}_title'),
            description: l10n.text('${key}_desc'),
          ),
        const SizedBox(height: 16),
        _infoRow(
          context,
          l10n.text('about_version_label'),
          info?.version ?? l10n.text('unavailable'),
        ),
        _infoRow(
          context,
          l10n.text('about_build_label'),
          info?.buildNumber.isNotEmpty == true ? info!.buildNumber : l10n.text('unavailable'),
        ),
        _infoRow(context, l10n.text('about_platform_label'), _computePlatformLabel()),
        const SizedBox(height: 32),
        Text(
          l10n.text('about_copyright'),
          style: text.bodySmall?.copyWith(color: design.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.text('about_made_with_love'),
          style: text.bodySmall?.copyWith(color: design.textSecondary),
        ),
      ],
    );
  }

  Widget _feature(
    BuildContext context, {
    required KnifeIcon icon,
    required String title,
    required String description,
  }) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PaperIcon(icon, color: context.design.accent, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: text.bodyMedium?.copyWith(color: context.design.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: context.design.textSecondary),
            ),
          ),
          Flexible(
            child: Text(value, style: text.titleSmall, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  static String _computePlatformLabel() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) return 'iOS';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'Android';
    if (kIsWeb) return 'Web';
    return 'Flutter';
  }
}
