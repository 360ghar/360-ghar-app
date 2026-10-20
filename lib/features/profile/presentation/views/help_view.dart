import 'package:flutter/material.dart';
import 'package:ghar360/core/data/models/bug_report_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/profile/presentation/widgets/profile_sheet_page.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Help: working contact routes, questions and fixes. Every row does what it
/// says; there are no placeholder actions.
class HelpView extends StatelessWidget {
  const HelpView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final design = context.design;
    Widget section(String key, {double top = 28}) => SheetSectionTitle(l10n.text(key), top: top);
    return ProfileSheetPage(
      title: l10n.text('help'),
      identifier: 'qa.profile.help.screen',
      maxWidth: 720,
      children: [
        section('help_quick_actions', top: 4),
        _action(
          context,
          icon: KnifeIcon.mail,
          title: l10n.text('help_email_support_title'),
          description: l10n.text('help_email_support_desc'),
          onTap: () => _emailSupport(context),
        ),
        _action(
          context,
          icon: KnifeIcon.alert,
          title: l10n.text('help_report_bug_title'),
          description: l10n.text('help_report_bug_desc'),
          onTap: () => context.push(AppRoutes.feedback, extra: BugType.uiBug),
        ),
        _action(
          context,
          icon: KnifeIcon.plus,
          title: l10n.text('help_request_feature_title'),
          description: l10n.text('help_request_feature_desc'),
          onTap: () => context.push(AppRoutes.feedback, extra: BugType.featureRequest),
        ),
        section('help_faq_title'),
        for (var i = 1; i <= 5; i++)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Text(l10n.text('help_faq_q$i'), style: text.titleMedium),
            children: [
              Text(
                l10n.text('help_faq_a$i'),
                style: text.bodyMedium?.copyWith(color: design.textSecondary),
              ),
            ],
          ),
        section('help_troubleshooting_title'),
        for (final topic in ['slow', 'cards', 'notifications'])
          _troubleshoot(
            context,
            title: l10n.text('help_troubleshoot_${topic}_title'),
            solutions: [for (var i = 1; i <= 4; i++) l10n.text('help_troubleshoot_${topic}_s$i')],
          ),
        section('help_contact_info_title'),
        _contact(
          context,
          icon: KnifeIcon.clock,
          title: l10n.text('help_contact_support_hours_title'),
          details: l10n.text('help_contact_support_hours_details'),
        ),
        _contact(
          context,
          icon: KnifeIcon.pin,
          title: l10n.text('help_contact_office_title'),
          details: l10n.text('help_contact_office_details'),
        ),
        _contact(
          context,
          icon: KnifeIcon.compass,
          title: l10n.text('help_contact_languages_title'),
          details: l10n.text('help_contact_languages_details'),
        ),
        section('help_feedback_title'),
        Text(
          l10n.text('help_feedback_body'),
          style: text.bodyMedium?.copyWith(color: design.textSecondary),
        ),
        const SizedBox(height: 16),
        Semantics(
          identifier: 'qa.profile.help.send_feedback',
          child: FilledButton(
            key: const ValueKey('qa.profile.help.send_feedback'),
            onPressed: () => context.push(AppRoutes.feedback),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: Text(l10n.text('send_feedback'), textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  Widget _action(
    BuildContext context, {
    required KnifeIcon icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    final design = context.design;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      titleAlignment: ListTileTitleAlignment.top,
      leading: PaperIcon(icon, color: design.accent, size: 22),
      title: Text(title),
      subtitle: Text(description),
      trailing: PaperIcon(KnifeIcon.chevronRight, color: design.textTertiary, size: 20),
      onTap: onTap,
    );
  }

  Widget _troubleshoot(
    BuildContext context, {
    required String title,
    required List<String> solutions,
  }) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium?.copyWith(color: context.design.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleSmall),
          const SizedBox(height: 6),
          for (final (index, solution) in solutions.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 24, child: Text('${index + 1}.', style: muted)),
                  Expanded(child: Text(solution, style: muted)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _contact(
    BuildContext context, {
    required KnifeIcon icon,
    required String title,
    required String details,
  }) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PaperIcon(icon, color: context.design.accent, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  details,
                  style: text.bodyMedium?.copyWith(color: context.design.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _emailSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@360ghar.com',
      query: 'subject=${Uri.encodeComponent('360Ghar App Support')}',
    );
    try {
      if (await launchUrl(uri)) return;
    } catch (_) {
      // A device without an email application can still read the support address.
    }
    if (context.mounted) {
      AppToast.info(
        context.l10n.text('help_email_title'),
        context.l10n.text('help_email_fallback'),
      );
    }
  }
}
