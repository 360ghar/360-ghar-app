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
    final deadline = _now().add(const Duration(seconds: resendCooldownSeconds));
    onTick(resendCooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
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
