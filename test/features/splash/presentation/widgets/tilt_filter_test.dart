import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/splash/presentation/widgets/tilt_filter.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

void main() {
  test('integrates rotation rates into a tilt and eases toward it', () {
    final tilt = TiltFilter();
    expect(tilt.settled, isTrue);
    tilt.addRate(0, 0, _ms(0)); // The first sample only sets the clock.
    tilt.addRate(1, 2, _ms(20));
    for (var i = 0; i < 20; i++) {
      tilt.step(_ms(16));
    }
    // Turning (y) drives x; tipping (x) drives y.
    expect(tilt.value.dx, greaterThan(tilt.value.dy));
    expect(tilt.value.dx, greaterThan(0));
    expect(tilt.settled, isFalse);
  });

  test('clamps the angle and ignores long gaps between samples', () {
    final tilt = TiltFilter(maxAngle: 0.3);
    tilt.addRate(0, 0, _ms(0));
    // A 5 s gap counts as 50 ms, so one sample cannot jump the scene.
    tilt.addRate(0, 100, const Duration(seconds: 5));
    tilt.step(const Duration(seconds: 1));
    expect(tilt.value.dx, lessThanOrEqualTo(1));
    for (var i = 1; i < 50; i++) {
      tilt.addRate(0, 100, _ms(5000 + i * 20));
    }
    tilt.step(_ms(16));
    expect(tilt.value.dx.abs(), lessThanOrEqualTo(1));
  });

  test('drifts back to the centre and settles', () {
    final tilt = TiltFilter();
    tilt.addRate(0, 0, _ms(0));
    tilt.addRate(3, 3, _ms(40));
    for (var i = 0; i < 400; i++) {
      tilt.step(_ms(16));
    }
    expect(tilt.settled, isTrue);
  });
}
