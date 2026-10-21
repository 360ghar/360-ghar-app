import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_media_hub.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../../helpers/fake_video_platform.dart';
import '../../../../helpers/provider_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeVideoPlatform platform;
  late VideoPlayerPlatform previous;
  setUp(() {
    previous = VideoPlayerPlatform.instance;
    platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  tearDown(() {
    VideoPlayerPlatform.instance = previous;
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpProviderApp(
      const Scaffold(
        body: PropertyMediaHub(
          property: PropertyModel(
            id: 1,
            title: 'Video property',
            basePrice: 1000,
            videoTourUrl: 'https://example.com/video.mp4',
            isAvailable: true,
            viewCount: 0,
            likeCount: 0,
            interestCount: 0,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Video Tour'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('video stays lazy, pauses in background, and disposes with sheet', (tester) async {
    await open(tester);
    expect(platform.events.length, 1);
    expect(find.byType(Chewie), findsOneWidget);
    final before = platform.paused.length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(platform.paused.length, greaterThan(before));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1)));
    expect(platform.disposed, [1]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('dismissal cancels incomplete initialization and its timer immediately', (
    tester,
  ) async {
    platform.initializeAutomatically = false;
    await open(tester);
    expect(find.byType(Skeleton), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1)));
    expect(platform.disposed, [1]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('timeout releases native player and offers explicit retry', (tester) async {
    platform.initializeAutomatically = false;
    await open(tester);
    await tester.pump(const Duration(seconds: 21));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1)));
    expect(platform.disposed, [1]);
    expect(find.text('Retry'), findsOneWidget);
    platform.initializeAutomatically = true;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(platform.events.length, 2);
    expect(find.byType(Chewie), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1)));
    expect(platform.disposed, [1, 2]);
    expect(tester.takeException(), isNull);
  });
}
