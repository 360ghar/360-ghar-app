import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/design/paper/paper_art.dart';
import 'package:ghar360/core/design/paper/paper_scene_data.dart';
import 'package:ghar360/features/splash/presentation/widgets/gurugram_diorama.dart';
import '../../../../helpers/provider_test_app.dart';

const _rect = Rect.fromLTWH(10, 100, 200, 300);

Matrix4? _at(
  String id,
  double page, {
  double depth = 0.5,
  Offset tilt = Offset.zero,
  bool reduce = false,
}) => dioramaTransform(
  id: id,
  depth: depth,
  rect: _rect,
  hingeY: 380,
  page: page,
  tilt: tilt,
  reduce: reduce,
);

bool _isTranslation(Matrix4 m) =>
    m.entry(0, 0) == 1 && m.entry(1, 1) == 1 && m.entry(1, 2) == 0 && m.entry(3, 2) == 0;

void main() {
  group('dioramaTransform', () {
    test('the city is always up; later layers fold up as their page arrives', () {
      expect(_at('towers', 0), isNotNull);
      expect(_at('street', 0), isNull);
      final mid = _at('street', 0.5)!;
      expect(_isTranslation(mid), isFalse, reason: 'half way the sheet is still folding');
      expect(_isTranslation(_at('street', 1)!), isTrue);
      expect(_at('home', 1), isNull);
      expect(_isTranslation(_at('home', 2)!), isTrue);
    });

    test('parallax follows the page and the tilt, scaled by depth', () {
      final near = _at('towers', 1, depth: 1)!.getTranslation().x;
      final far = _at('towers', 1, depth: 0.1)!.getTranslation().x;
      expect(near, lessThan(far));
      final tilted = _at('towers', 0, depth: 1, tilt: const Offset(1, 1))!.getTranslation();
      expect(tilted.x, _rect.left - 14);
      expect(tilted.y, _rect.top - 6);
    });

    test('the pin drops in, then lifts away as the home comes up', () {
      expect(_at('pin', 0.5)!.getTranslation().y, lessThan(_rect.top));
      expect(_at('pin', 1)!.getTranslation().y, _rect.top);
      expect(_at('pin', 1.5)!.getTranslation().y, lessThan(_rect.top - 100));
    });

    test('reduced motion jumps: no fold, no parallax', () {
      expect(_at('street', 0.4, reduce: true), isNull);
      final shown = _at('street', 0.6, reduce: true, tilt: const Offset(1, 1))!;
      expect(shown.getTranslation().x, _rect.left);
      expect(_isTranslation(shown), isTrue);
      expect(_at('pin', 2, reduce: true), isNull);
      expect(_at('pin', 1.2, reduce: true), isNotNull);
    });
  });

  group('baked layers', () {
    test('street parts and home parts bake as one sheet each; movers stay apart', () {
      final groups = dioramaGroups(gurugramArt.layers);
      final ids = [for (final g in groups) g.first.id];
      expect(ids, containsAll(['clouds', 'kite', 'train', 'pin', 'street', 'rooms']));
      expect(groups.firstWhere((g) => g.first.id == 'street').map((l) => l.id), contains('auto'));
      expect(groups.firstWhere((g) => g.first.id == 'rooms').map((l) => l.id), contains('home'));
      for (final g in groups) {
        expect(g.map((l) => l.depth).toSet(), hasLength(1), reason: g.first.id);
      }
      expect(groups.length, lessThanOrEqualTo(12));
    });

    test('a phone bakes under 32 MB at DPR 2', () {
      const size = Size(430, 932);
      final scale = math.max(size.width / gurugramArt.width, size.height / gurugramArt.height);
      final origin = Offset(
        (size.width - gurugramArt.width * scale) / 2,
        size.height - gurugramArt.height * scale,
      );
      final view = (Offset.zero & size).inflate(72);
      var bytes = 0.0;
      for (final group in dioramaGroups(gurugramArt.layers)) {
        var scene = paperLayerBounds(group.first, gurugramArt.shadow);
        for (final layer in group.skip(1)) {
          scene = scene.expandToInclude(paperLayerBounds(layer, gurugramArt.shadow));
        }
        final r = Rect.fromLTRB(
          origin.dx + scene.left * scale,
          origin.dy + scene.top * scale,
          origin.dx + scene.right * scale,
          origin.dy + scene.bottom * scale,
        ).intersect(view);
        if (r.width > 0 && r.height > 0) bytes += r.width * 2 * r.height * 2 * 4;
      }
      expect(bytes / 1e6, lessThan(32));
    });
  });

  group('GurugramDiorama', () {
    late StreamController<GyroscopeEvent> gyro;
    late PageController pages;
    setUp(() {
      gyro = StreamController<GyroscopeEvent>.broadcast();
      pages = PageController();
    });
    tearDown(() async {
      pages.dispose();
      await gyro.close();
    });

    Future<void> pump(WidgetTester tester, {bool still = false, bool dark = false}) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpProviderApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: still),
            child: Stack(
              children: [
                Positioned.fill(child: GurugramDiorama(pages: pages)),
                Positioned.fill(
                  child: PageView(
                    controller: pages,
                    children: const [SizedBox(), SizedBox(), SizedBox()],
                  ),
                ),
              ],
            ),
          ),
        ),
        theme: dark ? AppDesignTheme.dark() : AppDesignTheme.light(),
        overrides: [gyroscopeProvider.overrideWithValue(gyro.stream)],
      );
      // Let a theme change finish its animation.
      await tester.pump(const Duration(milliseconds: 400));
    }

    List<RenderRepaintBoundary> layers(WidgetTester tester) => [
      for (final element
          in find
              .byWidgetPredicate(
                (w) =>
                    w is RepaintBoundary &&
                    w.key is ValueKey &&
                    '${(w.key! as ValueKey).value}'.startsWith('diorama.layer.'),
              )
              .evaluate())
        element.renderObject! as RenderRepaintBoundary,
    ];

    List<Object?> images(WidgetTester tester) => [
      for (final raw in tester.widgetList<RawImage>(find.byType(RawImage))) raw.image,
    ];

    testWidgets('a swipe and a tilt recomposite the baked layers without repainting them', (
      tester,
    ) async {
      await pump(tester);
      final before = images(tester);
      expect(before, isNotEmpty);
      final boundaries = layers(tester);
      // Layers of later pages paint once, when they first come into view.
      final shown = {for (final b in boundaries) b: b.debugLayer != null};
      for (final boundary in boundaries) {
        boundary.debugResetMetrics();
      }
      final gesture = await tester.startGesture(const Offset(300, 400));
      for (var i = 0; i < 30; i++) {
        await gesture.moveBy(const Offset(-6, 0));
        gyro.add(GyroscopeEvent(0.2, 0.4, 0, DateTime(2030, 1, 1, 0, 0, 0, i * 20)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));
      for (final boundary in boundaries) {
        final paints = boundary.debugSymmetricPaintCount + boundary.debugAsymmetricPaintCount;
        expect(paints, lessThanOrEqualTo(shown[boundary]! ? 0 : 1));
      }
      expect(images(tester), before, reason: 'layers are baked once per size and theme');
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion never listens to the gyroscope', (tester) async {
      await pump(tester, still: true);
      expect(gyro.hasListener, isFalse);
      await tester.pumpAndSettle();
    });

    testWidgets('pausing the app stops the gyroscope; resuming starts it again', (tester) async {
      await pump(tester);
      expect(gyro.hasListener, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(gyro.hasListener, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(gyro.hasListener, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('a failing sensor is dropped quietly', (tester) async {
      await pump(tester);
      gyro.addError(StateError('no gyroscope'));
      await tester.pump();
      expect(gyro.hasListener, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });

    testWidgets('a new theme bakes new layers; disposal releases them', (tester) async {
      await pump(tester);
      final day = images(tester);
      await pump(tester, dark: true);
      expect(images(tester), isNot(day));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
