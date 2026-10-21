import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';

/// What a notification reports. The tone picks the icon and its colour; the
/// sheet itself is always paper with ink text.
enum ToastTone { success, error, warning, info }

/// Shared notification interface. The app's [AppToastHost] owns presentation.
class AppToast {
  AppToast._();

  static void Function(_ToastMessage)? _present;
  static VoidCallback? _dismiss;

  static void success(String title, [String? message]) =>
      custom(title: title, message: message ?? '', tone: ToastTone.success);

  static void error(String title, [String? message]) =>
      custom(title: title, message: message ?? '', tone: ToastTone.error);

  static void warning(String title, [String? message]) =>
      custom(title: title, message: message ?? '', tone: ToastTone.warning);

  static void info(String title, [String? message]) =>
      custom(title: title, message: message ?? '', tone: ToastTone.info);

  static void dismiss() => _dismiss?.call();

  static void custom({
    required String title,
    required String message,
    ToastTone tone = ToastTone.info,
    Duration duration = const Duration(seconds: 3),
    TextButton? mainButton,
  }) {
    _present?.call(
      _ToastMessage(
        title: title,
        message: message,
        tone: tone,
        duration: duration,
        mainButton: mainButton,
      ),
    );
  }
}

class _ToastMessage {
  const _ToastMessage({
    required this.title,
    required this.message,
    required this.tone,
    required this.duration,
    this.mainButton,
  });
  final String title;
  final String message;
  final ToastTone tone;
  final Duration duration;
  final TextButton? mainButton;
}

/// Put this in MaterialApp.builder, above its Navigator. Notifications stay at
/// the top across routes without a service locator or global BuildContext.
class AppToastHost extends StatefulWidget {
  const AppToastHost({super.key, required this.child});
  final Widget child;

  @override
  State<AppToastHost> createState() => _AppToastHostState();
}

class _AppToastHostState extends State<AppToastHost> {
  _ToastMessage? _message;
  Timer? _timer;
  int _revision = 0;
  late final void Function(_ToastMessage) _presenter = _show;
  late final VoidCallback _dismissCallback = _clear;

  @override
  void initState() {
    super.initState();
    AppToast._present = _presenter;
    AppToast._dismiss = _dismissCallback;
  }

  void _show(_ToastMessage message) {
    final revision = ++_revision;
    _timer?.cancel();
    void display() {
      if (!mounted || revision != _revision) return;
      setState(() => _message = message);
      // Give screen-reader users time to reach and activate an action.
      if (message.mainButton != null && MediaQuery.of(context).accessibleNavigation) return;
      _timer = Timer(message.duration, _clear);
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => display());
    } else {
      display();
    }
  }

  void _clear() {
    _revision++;
    _timer?.cancel();
    if (mounted && _message != null) setState(() => _message = null);
  }

  @override
  void dispose() {
    _revision++;
    _timer?.cancel();
    if (identical(AppToast._present, _presenter)) {
      AppToast._present = null;
      AppToast._dismiss = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    return Stack(
      children: [
        widget.child,
        if (message != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Dismissible(
                      key: ValueKey(message),
                      direction: DismissDirection.horizontal,
                      onDismissed: (_) => _clear(),
                      child: _ToastSheet(message: message),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The toast: a hand-cut paper slip that drops 10 px into place. It is
/// fully visible from the first frame; with reduced motion it does not move.
class _ToastSheet extends StatelessWidget {
  const _ToastSheet({required this.message});

  final _ToastMessage message;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final (icon, color) = switch (message.tone) {
      ToastTone.success => (KnifeIcon.check, design.success),
      ToastTone.error => (KnifeIcon.alert, design.error),
      ToastTone.warning => (KnifeIcon.alert, design.warning),
      ToastTone.info => (KnifeIcon.info, design.accent),
    };
    final text = Theme.of(context).textTheme;
    final sheet = Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        key: const ValueKey('qa.toast'),
        color: design.surface,
        shape: CutBorder(
          seed: 'toast',
          shadows: paperShadows(PaperElevation.high, design.shadowOn(design.background)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 12),
                child: PaperIcon(icon, size: 22, color: color),
              ),
              Expanded(
                child: DefaultTextStyle(
                  style: text.bodyMedium!.copyWith(color: design.textSecondary),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message.title, style: text.titleSmall),
                      if (message.message.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(message.message),
                      ],
                      if (message.mainButton != null)
                        Align(alignment: AlignmentDirectional.centerEnd, child: message.mainButton),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return sheet;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -10, end: 0),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, dy, child) => Transform.translate(offset: Offset(0, dy), child: child),
      child: sheet,
    );
  }
}
