import 'dart:math' as math;
import 'dart:ui';

/// Turns gyroscope rotation rates into a small, smooth tilt in -1..1.
///
/// Rates are integrated into an angle, clamped to [maxAngle], pulled back to
/// the centre over [recenter] (so drift never builds up) and eased over
/// [ease] so the scene never jitters.
class TiltFilter {
  TiltFilter({
    this.maxAngle = 0.3,
    this.recenter = const Duration(milliseconds: 800),
    this.ease = const Duration(milliseconds: 80),
  });

  final double maxAngle;
  final Duration recenter;
  final Duration ease;

  Offset _target = Offset.zero;
  Offset _value = Offset.zero;
  Duration? _lastEvent;

  /// The eased tilt: x follows turning left and right, y follows tipping.
  Offset get value => _value / maxAngle;

  /// Whether the scene has come to rest, so no frame is needed.
  bool get settled => _value.distance < 1e-3 && _target.distance < 1e-3;

  /// Adds one gyroscope sample: rotation rates in rad/s about the device's
  /// x axis (tipping) and y axis (turning), taken at [at].
  void addRate(double rateX, double rateY, Duration at) {
    final last = _lastEvent;
    _lastEvent = at;
    if (last == null) return;
    final dt = ((at - last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _target = _clamp(_target + Offset(rateY, rateX) * dt);
  }

  /// Advances the easing by [dt].
  void step(Duration dt) {
    final seconds = dt.inMicroseconds / 1e6;
    _target *= math.exp(-seconds / (recenter.inMicroseconds / 1e6));
    final k = 1 - math.exp(-seconds / (ease.inMicroseconds / 1e6));
    _value += (_target - _value) * k;
  }

  Offset _clamp(Offset o) =>
      Offset(o.dx.clamp(-maxAngle, maxAngle), o.dy.clamp(-maxAngle, maxAngle));
}
