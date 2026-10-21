import 'dart:async';

/// Recomputes elapsed time after app suspension and releases its timer on dispose.
class OtpResendTimer {
  OtpResendTimer(this.onTick, {DateTime Function()? now}) : _now = now ?? DateTime.now;
  static const int resendCooldownSeconds = 30;
  final void Function(int seconds) onTick;
  final DateTime Function() _now;
  Timer? _timer;
  void start() {
    cancel();
    var deadline = _now().add(const Duration(seconds: resendCooldownSeconds));
    onTick(resendCooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // A wall clock that moved back must not extend the wait.
      final latest = _now().add(const Duration(seconds: resendCooldownSeconds));
      if (latest.isBefore(deadline)) deadline = latest;
      final remaining = (deadline.difference(_now()).inMilliseconds / 1000).ceil().clamp(
        0,
        resendCooldownSeconds,
      );
      onTick(remaining);
      if (remaining == 0) cancel();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
