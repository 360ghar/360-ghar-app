// lib/core/widgets/common/app_update_dialog.dart

import 'package:flutter/material.dart';

import 'package:ghar360/core/controllers/app_update_controller.dart';
import 'package:ghar360/core/data/models/app_update_models.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/translations/app_localizations.dart';

export 'package:ghar360/core/controllers/app_update_controller.dart' show AppUpdateAction;

class AppUpdateDialog extends StatelessWidget {
  const AppUpdateDialog({
    super.key,
    required this.response,
    required this.currentVersion,
    this.onAction,
    this.busy = false,
    this.errorKey,
  });

  final AppVersionCheckResponse response;
  final String currentVersion;
  final ValueChanged<AppUpdateAction>? onAction;
  final bool busy;
  final String? errorKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMandatory = response.isMandatory;
    final releaseNotes = response.releaseNotes;
    final latestVersionLabel = response.latestVersion;
    final minSupportedVersion = response.minSupportedVersion;

    return PopScope(
      canPop: !isMandatory && !busy,
      child: AlertDialog(
        title: Text(
          isMandatory
              ? context.l10n.text('mandatory_update_required')
              : context.l10n.text('update_available'),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(semanticsLabel: context.l10n.text('loading')),
                ),
              if (errorKey != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      context.l10n.text(errorKey!),
                      style: theme.textTheme.bodyMedium?.copyWith(color: context.design.error),
                    ),
                  ),
                ),
              Text(
                '${context.l10n.text('current_version')}: $currentVersion',
                style: theme.textTheme.bodySmall?.copyWith(color: context.design.textSecondary),
              ),
              if (latestVersionLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${context.l10n.text('latest_version')}: $latestVersionLabel',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              if (minSupportedVersion != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${context.l10n.text('minimum_supported')}: $minSupportedVersion',
                    style: theme.textTheme.bodySmall?.copyWith(color: context.design.textSecondary),
                  ),
                ),
              if ((releaseNotes ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(releaseNotes!, style: theme.textTheme.bodyMedium),
                ),
              if ((releaseNotes ?? '').isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    isMandatory
                        ? context.l10n.text('mandatory_update_desc')
                        : context.l10n.text('optional_update_desc'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
            ],
          ),
        ),
        actions: _buildActions(context, isMandatory),
      ),
    );
  }

  void _act(BuildContext context, AppUpdateAction action) {
    if (onAction != null) {
      onAction!(action);
    } else {
      Navigator.of(context).pop(action);
    }
  }

  // ElevatedButton shares the FilledButton primary style in this theme; the
  // controller dialog test finds it by type.
  List<Widget> _buildActions(BuildContext context, bool isMandatory) {
    final update = ElevatedButton(
      onPressed: busy ? null : () => _act(context, AppUpdateAction.update),
      child: Text(context.l10n.text(isMandatory ? 'update_now' : 'update')),
    );
    if (isMandatory) return [update];
    return [
      TextButton(
        onPressed: busy ? null : () => _act(context, AppUpdateAction.remindLater),
        child: Text(context.l10n.text('not_now')),
      ),
      update,
    ];
  }
}
