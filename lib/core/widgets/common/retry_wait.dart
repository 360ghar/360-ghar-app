import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:ghar360/core/utils/error_message.dart';

/// Counts down the wait a failure asks for (a 429 `Retry-After`) and rebuilds
/// once a second. [builder] gets the seconds left, 0 when retry is allowed.
/// Key it by the failure so a new failure restarts the count.
class RetryWait extends StatefulWidget {
  const RetryWait({super.key, required this.error, required this.builder});

  final Object? error;
  final Widget Function(BuildContext context, int secondsLeft) builder;

  @override
  State<RetryWait> createState() => _RetryWaitState();
}

class _RetryWaitState extends State<RetryWait> {
  Timer? _timer;
  int _left = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(RetryWait oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.error, widget.error)) _start();
  }

  void _start() {
    _timer?.cancel();
    final wait = retryWaitOf(widget.error);
    // Round up so a fractional wait never re-enables the action early.
    _left = wait == null ? 0 : (wait.inMilliseconds + 999) ~/ 1000;
    if (_left <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _left);
}
