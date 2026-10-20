import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/controllers/app_update_controller.dart';
import 'package:ghar360/core/widgets/common/app_update_dialog.dart';

/// Owns update prompts and foreground checks for the mounted app navigator.
class AppUpdateHost extends ConsumerStatefulWidget {
  const AppUpdateHost({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.enabled = true,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final bool enabled;
  @override
  ConsumerState<AppUpdateHost> createState() => _AppUpdateHostState();
}

class _AppUpdateHostState extends ConsumerState<AppUpdateHost> with WidgetsBindingObserver {
  bool _showing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleCheck();
  }

  @override
  void didUpdateWidget(covariant AppUpdateHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) _scheduleCheck();
  }

  void _scheduleCheck() {
    if (!widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) unawaited(_checkAndShow());
    });
  }

  Future<void> _checkAndShow() async {
    if (!widget.enabled) return;
    await ref.read(appUpdateProvider.notifier).checkForUpdates();
    if (mounted && widget.enabled) await _showPrompt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.enabled) unawaited(_checkAndShow());
  }

  void _schedulePrompt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showPrompt());
    });
  }

  Future<void> _showPrompt() async {
    if (_showing || !mounted || !widget.enabled) return;
    final state = ref.read(appUpdateProvider);
    final prompt = state.prompt;
    final context = widget.navigatorKey.currentState?.overlay?.context;
    if (prompt == null || context == null) return;
    _showing = true;
    final container = ProviderScope.containerOf(this.context);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !prompt.isMandatory,
        builder: (dialogContext) => UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(appUpdateProvider);
              return AppUpdateDialog(
                response: prompt,
                currentVersion: state.version?.version ?? '',
                busy: state.action.isLoading,
                errorKey: state.actionErrorKey,
                onAction: (action) async {
                  final completed = await ref.read(appUpdateProvider.notifier).act(action);
                  if (context.mounted && completed) Navigator.of(dialogContext).pop();
                },
              );
            },
          ),
        ),
      );
      if (!mounted) return;
      // Barrier/back dismissals retain the same optional-version skip behavior.
      if (identical(ref.read(appUpdateProvider).prompt, prompt) && !prompt.isMandatory) {
        await ref.read(appUpdateProvider.notifier).act(AppUpdateAction.remindLater);
      }
    } finally {
      _showing = false;
      if (mounted && ref.read(appUpdateProvider).prompt != null) _schedulePrompt();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appUpdateProvider, (_, next) {
      if (next.prompt != null && !_showing) _schedulePrompt();
    });
    return widget.child;
  }
}
