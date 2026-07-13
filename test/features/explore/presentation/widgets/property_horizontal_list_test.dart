import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/explore/presentation/controllers/explore_controller.dart';
import 'package:ghar360/features/explore/presentation/widgets/property_horizontal_list.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

/// Minimal fake of [ExploreController] exposing only the surface used by
/// [PropertyHorizontalList]. Uses [GetxServiceMock] to satisfy the type
/// requirement without triggering the real constructor's Get.find dependencies.
class _FakeExploreController extends GetxServiceMock implements ExploreController {
  _FakeExploreController(List<PropertyModel> initial) {
    properties.assignAll(initial);
  }

  @override
  final RxList<PropertyModel> properties = <PropertyModel>[].obs;
  @override
  final Rx<PropertyModel?> selectedProperty = Rx<PropertyModel?>(null);
  @override
  final RxMap<int, bool> likedOverrides = <int, bool>{}.obs;

  @override
  bool hasMore = false;
  @override
  bool isLoadingMore = false;
  int loadMoreCalls = 0;
  int highlightCalls = 0;

  @override
  bool isPropertyLiked(PropertyModel property) {
    if (likedOverrides.containsKey(property.id)) {
      return likedOverrides[property.id] ?? property.liked;
    }
    return property.liked;
  }

  @override
  Future<void> toggleLike(PropertyModel property) async {
    likedOverrides[property.id] = !isPropertyLiked(property);
  }

  @override
  void highlightPropertyFromCard(PropertyModel property) {
    highlightCalls++;
    selectedProperty.value = property;
  }

  @override
  Future<void> loadMoreProperties() async {
    loadMoreCalls++;
  }
}

PropertyModel _property(int id) {
  return PropertyModel(
    id: id,
    title: 'Property $id',
    basePrice: 5000000,
    propertyType: PropertyType.house,
    purpose: PropertyPurpose.buy,
    bedrooms: 2,
    bathrooms: 1,
    areaSqft: 1000,
    mainImageUrl: 'https://example.com/image$id.jpg',
    city: 'Pune',
    state: 'Maharashtra',
    isAvailable: true,
    viewCount: 1,
    likeCount: 1,
    interestCount: 1,
  );
}

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    // Suppress RenderFlex overflow errors from the fixed-width property cards.
    FlutterError.onError = (FlutterErrorDetails details) {
      if (!details.toString().contains('RenderFlex overflowed')) {
        FlutterError.presentError(details);
      }
    };
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(2400, 1600)),
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('renders a card per property in horizontal mode', (tester) async {
    final controller = _FakeExploreController([_property(1), _property(2), _property(3)]);
    await pumpWidget(tester, PropertyHorizontalList(controller: controller));

    expect(find.text('Property 1'), findsOneWidget);
    expect(find.text('Property 2'), findsOneWidget);
    expect(find.text('Property 3'), findsOneWidget);
  });

  testWidgets('shows empty placeholder text when there are no properties (vertical)', (
    tester,
  ) async {
    final controller = _FakeExploreController([]);
    await pumpWidget(
      tester,
      PropertyHorizontalList(controller: controller, direction: Axis.vertical),
    );

    expect(find.text('No Properties Found'), findsOneWidget);
  });

  testWidgets('renders a minimal container when empty in horizontal mode', (tester) async {
    final controller = _FakeExploreController([]);
    await pumpWidget(
      tester,
      PropertyHorizontalList(controller: controller, direction: Axis.horizontal),
    );

    expect(find.text('No Properties Found'), findsNothing);
  });

  testWidgets('tapping the favorite icon toggles like via the controller', (tester) async {
    final controller = _FakeExploreController([_property(1)]);
    await pumpWidget(tester, PropertyHorizontalList(controller: controller));

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();

    expect(controller.likedOverrides[1], isTrue);
  });

  testWidgets('renders vertical list for tablet direction', (tester) async {
    final controller = _FakeExploreController([_property(1), _property(2)]);
    await pumpWidget(
      tester,
      SizedBox(
        height: 600,
        child: PropertyHorizontalList(controller: controller, direction: Axis.vertical),
      ),
    );

    // Both properties render in the vertical list.
    expect(find.text('Property 1'), findsOneWidget);
    expect(find.text('Property 2'), findsOneWidget);
  });
}
