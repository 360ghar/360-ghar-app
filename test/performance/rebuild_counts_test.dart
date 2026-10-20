import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/features/discover/presentation/controllers/discover_controller.dart';
import 'package:ghar360/features/discover/presentation/views/discover_view.dart';
import 'package:ghar360/features/explore/presentation/views/explore_view.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../helpers/explore_test_harness.dart';
import '../helpers/fake_explore_map_platform.dart';
import '../helpers/load_app_fonts.dart';
import '../helpers/property_query_test_support.dart';
import '../helpers/property_screen_harness.dart';
import '../helpers/provider_test_app.dart';

/// Counts dirty builds (rebuilds and mounts) per widget type while [action]
/// runs. This is the same signal DevTools "Track widget rebuilds" reads.
Future<Map<String, int>> _countRebuilds(Future<void> Function() action) async {
  final counts = <String, int>{};
  final prior = debugOnRebuildDirtyWidget;
  debugOnRebuildDirtyWidget = (element, builtOnce) {
    final name = element.widget.runtimeType.toString();
    counts[name] = (counts[name] ?? 0) + 1;
    prior?.call(element, builtOnce);
  };
  try {
    await action();
  } finally {
    debugOnRebuildDirtyWidget = prior;
  }
  return counts;
}

const _screenWidgets = [
  'DiscoverView',
  'PropertySwipeStack',
  'PropertySwipeCard',
  'ExploreView',
  'ExploreMap',
  'PropertyHorizontalList',
  'PropertyListCard',
];

Map<String, Object?> _summary(String workload, Map<String, int> counts) {
  final top = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return {
    'workload': workload,
    'totalDirtyBuilds': counts.values.fold<int>(0, (sum, value) => sum + value),
    'screenWidgets': {for (final name in _screenWidgets) name: counts[name] ?? 0},
    'top': {for (final entry in top.take(12)) entry.key: entry.value},
  };
}

PropertyModel _property(int id) => PropertyModel(
  id: id,
  title: 'Garden Court Residence $id',
  basePrice: 8500000,
  propertyType: PropertyType.apartment,
  purpose: PropertyPurpose.buy,
  bedrooms: 3,
  bathrooms: 2,
  areaSqft: 1450,
  city: 'Gurugram',
  state: 'Haryana',
  isAvailable: true,
  viewCount: 24,
  likeCount: 8,
  interestCount: 3,
);

/// Publishes the same first state change as [SwipeHistory.record] (the entry,
/// and the card hidden from the deck) without the SQLite write, so the count
/// covers only the widget work a swipe causes.
class _InstantHistory extends ScreenHistory {
  var _revision = 0;
  @override
  Future<bool> record(PropertyModel property, bool isLiked, {bool restored = false}) {
    emit(
      state.copyWith(
        entries: {
          ...state.entries,
          property.id: SwipeEntry(
            property: property,
            isLiked: isLiked,
            revision: ++_revision,
            phase: SwipePhase.submitting,
          ),
        },
        excluded: {...state.excluded, property.id},
      ),
    );
    return Future.value(true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  final samples = <Map<String, Object?>>[];

  testWidgets('discover: 5 committed swipes', (tester) async {
    final data = (await tester.runAsync(PropertyQueryHarness.create))!;
    final harness = PropertyScreenHarness(
      data,
      pages: {
        PropertyFeed.discover: PropertyPageState(
          phase: PropertyLoadPhase.content,
          items: List.generate(10, (index) => _property(index + 1)),
        ),
      },
      historyFactory: _InstantHistory.new,
    );
    await harness.pump(tester, const DiscoverView());
    final controller = harness.container.read(discoverProvider.notifier);
    final counts = await _countRebuilds(() async {
      for (var swipe = 0; swipe < 5; swipe++) {
        await controller.swipeRight(controller.deck.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
      }
    });
    samples.add(_summary('discover_commit_5_swipes', counts));
    expect(counts, isNotEmpty);
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });

  testWidgets('explore: 5 camera moves and 5 card highlights', (tester) async {
    final original = MapLibrePlatform.createInstance;
    MapLibrePlatform.createInstance = FakeExploreMapPlatform.new;
    final harness = ExploreTestHarness(
      items: [for (var id = 1; id <= 8; id++) exploreProperty(id)],
    );
    addTearDown(() async {
      MapLibrePlatform.createInstance = original;
      await harness.dispose();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpProviderApp(
      UncontrolledProviderScope(container: harness.container, child: const ExploreView()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final camera = await _countRebuilds(() async {
      for (var move = 0; move < 5; move++) {
        harness.controller.onCameraIdle(LatLng(28.6 + move * 0.01, 77.2), 13);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
      }
    });
    samples.add(_summary('explore_camera_5_moves', camera));
    final highlight = await _countRebuilds(() async {
      for (var id = 1; id <= 5; id++) {
        harness.controller.highlightPropertyFromCard(exploreProperty(id));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
      }
    });
    samples.add(_summary('explore_card_5_highlights', highlight));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  tearDownAll(() async {
    if (!const bool.fromEnvironment('WRITE_INTERACTION_METRICS')) return;
    final file = File('build/verification/rebuild-counts.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert({'samples': samples}));
  });
}
