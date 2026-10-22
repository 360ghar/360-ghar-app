import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/routes/route_policy.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/symmetric_safe_area.dart';
import 'package:go_router/go_router.dart';

enum _Pick { signIn, policy }

/// The one gate for account features. Returns true when a user is signed in.
/// A guest gets a sheet that offers sign-in and returns false: the action is
/// not resumed after sign-in, the user lands back where they were.
Future<bool> requireAccount(BuildContext context, WidgetRef ref, {String? returnTo}) async {
  if (ref.read(storageScopeProvider).accountId != null) return true;
  final router = GoRouter.maybeOf(context);
  final back = returnTo ?? router?.routeInformationProvider.value.uri.toString();
  final pick = await showModalBottomSheet<_Pick>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _SignInSheet(),
  );
  if (pick == null || router == null) return false;
  switch (pick) {
    case _Pick.signIn:
      router.push(routeWithReturn(AppRoutes.phoneEntry, back));
    case _Pick.policy:
      router.push('/policy/privacy-policy');
  }
  return false;
}

class _SignInSheet extends StatelessWidget {
  const _SignInSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return SymmetricSafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.text('sign_in_required_title'),
                style: text.headlineMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.text('sign_in_required_message'),
              style: text.bodyMedium?.copyWith(color: context.design.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                identifier: 'qa.sign_in_gate.sign_in',
                child: FilledButton(
                  key: const ValueKey('qa.sign_in_gate.sign_in'),
                  onPressed: () => Navigator.of(context).pop(_Pick.signIn),
                  child: Text(l10n.text('sign_in')),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Semantics(
              identifier: 'qa.sign_in_gate.not_now',
              child: TextButton(
                key: const ValueKey('qa.sign_in_gate.not_now'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.text('not_now')),
              ),
            ),
            TextButton(
              key: const ValueKey('qa.sign_in_gate.policy'),
              onPressed: () => Navigator.of(context).pop(_Pick.policy),
              child: Text(l10n.text('privacy_policy_item_title')),
            ),
          ],
        ),
      ),
    );
  }
}
