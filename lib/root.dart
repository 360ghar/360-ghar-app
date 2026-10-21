import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/error_message.dart';
import 'package:ghar360/core/widgets/common/app_boot_loader.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';

/// Resolving/error route only. go_router redirects settled states directly.
class Root extends ConsumerWidget {
  const Root({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final actions = ref.read(authProvider.notifier);
    if (auth.status == AuthStatus.error) {
      return Scaffold(
        body: SafeArea(
          child: ErrorStates.profileLoadError(
            customMessage: errorMessage(context, auth.error),
            onRetry: auth.resolving ? null : actions.retryProfileLoad,
            onSignOut: auth.mutation.isLoading ? null : actions.signOut,
            isRetrying: auth.resolving,
          ),
        ),
      );
    }
    return AppBootLoader(
      message: context.l10n.text(auth.resolving ? 'checking_session' : 'starting_app'),
      onRetry: actions.recheckAuthBootstrap,
    );
  }
}
