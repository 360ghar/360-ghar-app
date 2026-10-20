import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:ghar360/core/design/paper/paper_art.dart';
import 'package:ghar360/core/design/paper/paper_scene_data.dart';
import 'package:ghar360/core/widgets/paper/baked_paper_scene.dart';
import 'package:ghar360/features/splash/presentation/widgets/tilt_filter.dart';

/// Gyroscope samples for tilt parallax. Empty on the web; tests override it.
final gyroscopeProvider = Provider<Stream<GyroscopeEvent>>(
  (ref) => kIsWeb
      ? const Stream.empty()
      : gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval),
);

/// The onboarding page on which each layer of the Gurugram street appears:
/// the city first, then the street with a pin, then a home with a lit window.
const dioramaPages = {
  'sky': 0,
  'clouds': 0,
  'towers': 0,
  'kite': 0,
  'blocks': 0,
  'metro': 1,
  'train': 1,
  'street': 1,
  'shops': 1,
  'posts': 1,
  'stall': 1,
  'trunks': 1,
  'trees': 1,
  'auto': 1,
  'cow': 1,
  'umbrella': 1,
  'cart': 1,
  'veg': 1,
  'kerb': 1,
  'pin': 1,
  'rooms': 2,
  'lit': 2,
  'home': 2,
  'parapet': 2,
  'hometank': 2,
};

/// Layer images are baked at most at this pixel ratio (memory knob).
const kDioramaMaxRasterDpr = kPaperSceneMaxRasterDpr;

/// The street level in scene units; new layers fold up from here.
const _streetY = 800.0;

/// The highest scene row a wide screen may crop to: the sun starts at 165.
/// Past it, the ground below the street is cropped instead.
const _keepTop = 125.0;

/// Where [layer] sits on screen for page position [page]. Null hides it.
///
/// Layers of later pages fold up from the street like card stock as their
/// page comes in; the pin drops instead. Every layer shifts by its depth with
/// the page swipe and the device tilt. With [reduce] nothing moves: a layer
/// is either down or up.
@visibleForTesting
Matrix4? dioramaTransform({
  required String id,
  required double depth,
  required Rect rect,
  required double hingeY,
  required double page,
  Offset tilt = Offset.zero,
  bool reduce = false,
  double drift = 0,
}) {
  final appears = dioramaPages[id] ?? 0;
  final double fold;
  if (appears == 0) {
    fold = 1;
  } else if (reduce) {
    fold = page.round() >= appears ? 1 : 0;
  } else {
    fold = Curves.easeInOutCubic.transform((page - appears + 1).clamp(0.0, 1.0));
  }
  if (fold <= 0) return null;
  final dx = reduce ? 0.0 : (-page * 18 - tilt.dx * 14) * depth + drift;
  final dy = reduce ? 0.0 : -tilt.dy * 6 * depth;
  final m = Matrix4.translationValues(rect.left + dx, rect.top + dy, 0);
  // The pin has found the place: it lifts away as the home comes up.
  if (id == 'pin' && page > 1) {
    if (reduce) return page.round() >= 2 ? null : m;
    return m
      ..translateByDouble(0, -Curves.easeIn.transform((page - 1).clamp(0.0, 1.0)) * 900, 0, 1);
  }
  if (fold >= 1) return m;
  if (id == 'pin') return m..translateByDouble(0, -(1 - fold) * 180, 0, 1);
  final hinge = hingeY - rect.top;
  return m
    ..translateByDouble(0, hinge, 0, 1)
    ..multiply(Matrix4.identity()..setEntry(3, 2, 0.0015))
    ..rotateX(-(1 - fold) * math.pi / 2)
    ..translateByDouble(0, -hinge, 0, 1);
}

/// The Gurugram street, painted once into one image per layer and moved with
/// transforms. A page swipe or a tilt only recomposites; nothing repaints.
class GurugramDiorama extends ConsumerStatefulWidget {
  const GurugramDiorama({super.key, required this.pages});

  /// The onboarding page controller; its offset drives the fold and parallax.
  final PageController pages;

  @override
  ConsumerState<GurugramDiorama> createState() => _GurugramDioramaState();
}

/// Layers that drift or move on their own keep their own image.
const _movesAlone = {'clouds', 'kite', 'train', 'pin'};

/// Runs of layers that share a depth and a page move as one sheet, so each run
/// is baked into one image: the street's many coloured parts cost one image
/// and one composited layer, not eleven.
@visibleForTesting
List<List<PaperLayerData>> dioramaGroups(List<PaperLayerData> layers) {
  final groups = <List<PaperLayerData>>[];
  for (final layer in layers) {
    final head = groups.isEmpty ? null : groups.last.first;
    final joins =
        head != null &&
        !_movesAlone.contains(head.id) &&
        !_movesAlone.contains(layer.id) &&
        head.depth == layer.depth &&
        (dioramaPages[head.id] ?? 0) == (dioramaPages[layer.id] ?? 0);
    if (joins) {
      groups.last.add(layer);
    } else {
      groups.add([layer]);
    }
  }
  return groups;
}

class _GurugramDioramaState extends ConsumerState<GurugramDiorama>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  late final AppLifecycleListener _lifecycle;
  final _frame = ValueNotifier<int>(0);
  final _tilt = TiltFilter();
  StreamSubscription<GyroscopeEvent>? _gyro;
  var _sensorFailed = false;
  var _resumed = true;
  Duration _lastTick = Duration.zero;
  Duration _clock = Duration.zero;

  /// Ambient motion plays for [_moment] after each page settles, then the
  /// scene rests and the ticker stops (unless the device tilts).
  static const _moment = Duration(seconds: 5);
  Duration _momentStart = Duration.zero;
  int? _settledPage;

  static final _groups = dioramaGroups(gurugramArt.layers);

  @override
  void initState() {
    super.initState();
    widget.pages.addListener(_onPage);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _resumed = state == AppLifecycleState.resumed;
        _sync();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  bool get _still => MediaQuery.disableAnimationsOf(context);

  bool get _active => !_still && TickerMode.valuesOf(context).enabled && _resumed;

  /// A page that comes to rest starts a new ambient moment.
  void _onPage() {
    final pages = widget.pages;
    if (!pages.hasClients || pages.positions.length != 1) return;
    final page = pages.page ?? 0;
    if ((page - page.round()).abs() > 0.001 || page.round() == _settledPage) return;
    _settledPage = page.round();
    _momentStart = _clock;
    _wake();
  }

  void _wake() {
    if (mounted && _active && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  /// Runs the clock and the gyroscope only while motion is allowed, the
  /// route is visible and the app is in front.
  void _sync() {
    if (!mounted) return;
    final active = _active;
    if (active) {
      // The first page starts the first moment.
      if (_settledPage == null) {
        _settledPage = 0;
        _momentStart = _clock;
      }
      if (_clock - _momentStart < _moment) _wake();
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
    if (active && _gyro == null && !_sensorFailed) {
      _gyro = ref
          .read(gyroscopeProvider)
          .listen(
            (event) {
              _tilt.addRate(
                event.x,
                event.y,
                Duration(microseconds: event.timestamp.microsecondsSinceEpoch),
              );
              _wake();
            },
            onError: (Object _) {
              _sensorFailed = true;
              _gyro?.cancel();
              _gyro = null;
            },
          );
    } else if (!active) {
      _gyro?.cancel();
      _gyro = null;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero ? Duration.zero : elapsed - _lastTick;
    _lastTick = elapsed;
    _clock += dt;
    _tilt.step(dt);
    _frame.value++;
    if (_clock - _momentStart >= _moment && _tilt.settled) _ticker.stop();
  }

  /// Seconds into the current ambient moment, or null once it has ended.
  double? get _momentProgress {
    final t = (_clock - _momentStart).inMicroseconds / _moment.inMicroseconds;
    return t >= 1 ? null : t;
  }

  @override
  void dispose() {
    widget.pages.removeListener(_onPage);
    _ticker.dispose();
    _lifecycle.dispose();
    _gyro?.cancel();
    _frame.dispose();
    super.dispose();
  }

  double get _page {
    final pages = widget.pages;
    return pages.hasClients && pages.positions.length == 1 ? pages.page ?? 0 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _still;
    return BakedPaperScene(
      key: const ValueKey('qa.splash.diorama'),
      art: gurugramArt,
      groups: _groups,
      keepTop: _keepTop,
      layerKeyPrefix: 'diorama.layer.',
      repaint: Listenable.merge([widget.pages, _frame]),
      transform: (b, size) {
        final p = reduce ? null : _momentProgress;
        return dioramaTransform(
          id: b.layer.id,
          depth: b.layer.depth,
          rect: b.rect,
          hingeY: b.sceneY(_streetY),
          page: _page,
          tilt: _tilt.value,
          reduce: reduce,
          drift: p == null ? 0 : _drift(b.layer.id, _settledPage ?? 0, p, size.width),
        );
      },
    );
  }

  /// Authored motion for one moment ([p] from 0 to 1) after a page settles.
  /// Every curve ends at rest, so the scene stops exactly where it began:
  /// on the city the kite sways and the clouds drift; on the street the
  /// metro train runs off to the right and comes back from the left.
  static double _drift(String id, int page, double p, double width) => switch (id) {
    'clouds' => math.sin(p * math.pi) * 10,
    'kite' when page == 0 => math.sin(p * 4 * math.pi) * 7 * (1 - p),
    'train' when page == 1 => _train(p) * width * 1.3,
    _ => 0,
  };

  static double _train(double p) {
    if (p < 0.1) return 0;
    if (p < 0.45) return Curves.easeIn.transform((p - 0.1) / 0.35);
    return -1 + Curves.easeOutCubic.transform((p - 0.45) / 0.55);
  }
}
