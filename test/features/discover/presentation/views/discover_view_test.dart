// test/features/discover/presentation/views/discover_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/discover/presentation/controllers/discover_controller.dart';
import 'package:ghar360/features/discover/presentation/views/discover_view.dart';
import 'package:ghar360/features/discover/presentation/widgets/property_swipe_stack.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Mock PageStateService — provides the reactive page states and the handful
// of helpers the DiscoverTopBar / LocationSelector read while rendering.
// ---------------------------------------------------------------------------

class _MockPageStateService extends GetxServiceMock implements PageStateService {
  @override
  final Rx<PageStateModel> discoverState = PageStateModel.initial(PageType.discover).obs;
  @override
  final Rx<PageStateModel> likesState = PageStateModel.initial(PageType.likes).obs;
  @override
  final Rx<PageStateModel> exploreState = PageStateModel.initial(PageType.explore).obs;
  @override
  final Rx<PageType> currentPageType = PageType.discover.obs;

  final RxBool _discoverRefreshing = false.obs;

  @override
  bool isSearchVisible(PageType pageType) => false;

  @override
  bool isPageRefreshing(PageType pageType) {
    // Read the reactive flag so the Obx in UnifiedTopBar detects an observable.
    if (pageType == PageType.discover) return _discoverRefreshing.value;
    return false;
  }

  @override
  PageStateModel getStateForPage(PageType pageType) {
    switch (pageType) {
      case PageType.explore:
        return exploreState.value;
      case PageType.discover:
        return discoverState.value;
      case PageType.likes:
        return likesState.value;
    }
  }

  @override
  String get currentLikesSegment =>
      likesState.value.getAdditionalData<String>('currentSegment') ?? 'liked';
}

// ---------------------------------------------------------------------------
// Test DiscoverController — skips the onInit/onReady workers that wire up
// page-activation and state-sync listeners, so tests drive state directly.
// ---------------------------------------------------------------------------

class _TestDiscoverController extends DiscoverController {
  @override
  void onInit() {
    // No state-sync worker; tests set [state] explicitly.
  }

  @override
  void onReady() {
    // No page-activation worker or auto-loading.
  }
}

PropertyModel _property({int id = 100}) => testPropertyModel(id: id);

/// Pumps the DiscoverView while suppressing RenderFlex overflow errors that
/// the shimmer skeletons emit under the constrained test surface.
Future<void> _pumpDiscover(WidgetTester tester) async {
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.summary.toString().contains('overflowed')) return;
    FlutterError.presentError(details);
  };
  await tester.pumpApp(const DiscoverView());
}

void main() {
  late _MockPageStateService pageStateService;
  late _TestDiscoverController controller;

  void Function(FlutterErrorDetails)? originalOnError;

  setUp(() {
    GetxTestBinding.init();
    pageStateService = _MockPageStateService();
    // Suppress RenderFlex overflow errors thrown by skeleton/shimmer widgets
    // under the constrained test surface size.
    originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final summary = details.summary.toString();
      if (summary.contains('overflowed')) return;
      originalOnError?.call(details);
    };
    // Register PageStateService before constructing the controller, since
    // DiscoverController resolves it in a field initializer.
    GetxTestBinding.bind()
      ..register<PageStateService>(pageStateService)
      ..register<LocationController>(_FakeLocationController());
    controller = _TestDiscoverController();
    GetxTestBinding.bind().register<DiscoverController>(controller);
  });

  tearDown(() {
    FlutterError.onError = originalOnError;
    GetxTestBinding.reset();
  });

  group('DiscoverView', () {
    testWidgets('renders screen semantics and top bar', (tester) async {
      controller.state.value = DiscoverState.loading;

      await _pumpDiscover(tester);

      expect(find.byKey(const ValueKey('qa.discover.screen')), findsOneWidget);
    });

    testWidgets('shows loading state with skeleton', (tester) async {
      controller.state.value = DiscoverState.loading;
      controller.isPrefetching.value = false;

      await _pumpDiscover(tester);

      expect(find.byIcon(Icons.travel_explore_rounded), findsOneWidget);
      expect(find.text('discovering_properties_message'.tr), findsOneWidget);
    });

    testWidgets('shows loading state with prefetch indicator', (tester) async {
      controller.state.value = DiscoverState.loading;
      controller.isPrefetching.value = true;

      await _pumpDiscover(tester);

      expect(find.text('loading_more_properties'.tr), findsOneWidget);
    });

    testWidgets('shows error state with retry button', (tester) async {
      controller.state.value = DiscoverState.error;
      controller.error.value = NetworkException('Connection failed');

      await tester.pumpApp(const DiscoverView());
      await tester.pump();

      expect(find.text('Connection failed'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('error state with null error renders empty SizedBox', (tester) async {
      controller.state.value = DiscoverState.error;
      controller.error.value = null;

      await tester.pumpApp(const DiscoverView());
      await tester.pump();

      // No error text shown when error is null.
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('shows empty state with refresh and change filters buttons', (tester) async {
      controller.state.value = DiscoverState.empty;

      await tester.pumpApp(const DiscoverView());
      await tester.pump();

      expect(find.text('no_more_properties'.tr), findsOneWidget);
      expect(find.text('change_filters'.tr), findsOneWidget);
      expect(find.text('refresh'.tr), findsOneWidget);
    });

    testWidgets('shows swipe interface when loaded', (tester) async {
      pageStateService.discoverState.value = PageStateModel(
        pageType: PageType.discover,
        filters: const UnifiedFilterModel(),
        properties: [_property(id: 1), _property(id: 2)],
      );
      controller.state.value = DiscoverState.loaded;
      controller.totalSwipesInSession.value = 5;

      await tester.pumpApp(const DiscoverView());
      await tester.pump();

      expect(find.byType(PropertySwipeStack), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.discover.swipe_stack')), findsOneWidget);
    });

    testWidgets('loaded state shows action buttons outside the swipe stack card', (tester) async {
      pageStateService.discoverState.value = PageStateModel(
        pageType: PageType.discover,
        filters: const UnifiedFilterModel(),
        properties: [_property(id: 1)],
      );
      controller.state.value = DiscoverState.loaded;

      await tester.pumpApp(const DiscoverView());
      await tester.pump();

      expect(find.byType(PropertySwipeStack), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.discover.action.like')), findsOneWidget);
      expect(find.text('Swipe right to like | Swipe left to pass'), findsNothing);
    });

    testWidgets('prefetching state renders swipe interface', (tester) async {
      pageStateService.discoverState.value = PageStateModel(
        pageType: PageType.discover,
        filters: const UnifiedFilterModel(),
        properties: [_property(id: 1)],
      );
      controller.state.value = DiscoverState.prefetching;

      await tester.pumpApp(const DiscoverView());
      await tester.pump();

      expect(find.byType(PropertySwipeStack), findsOneWidget);
    });

    testWidgets('shows refresh indicator when page is refreshing', (tester) async {
      pageStateService.discoverState.value = PageStateModel(
        pageType: PageType.discover,
        filters: const UnifiedFilterModel(),
        properties: [_property(id: 1)],
        isRefreshing: true,
      );
      controller.state.value = DiscoverState.loaded;

      await tester.pumpApp(const DiscoverView());
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Minimal fake LocationController for the top bar's LocationSelector.
// ---------------------------------------------------------------------------

class _FakeLocationController extends LocationController {
  @override
  void clearPlaceSuggestions() {}

  @override
  bool get hasLocation => false;
}
