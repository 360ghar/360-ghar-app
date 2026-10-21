import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/providers/pending_actions_provider.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/widgets/common/property_list_card.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/paper_vignette.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import 'package:ghar360/features/property_details/presentation/controllers/property_details_controller.dart';
import 'package:ghar360/features/property_details/presentation/views/property_details_view.dart';
import 'package:ghar360/features/property_details/presentation/widgets/fullscreen_photo_gallery.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import '../../../../helpers/knife_finders.dart';
import '../../../../helpers/provider_test_app.dart';
import '../../../../helpers/visits_test_support.dart';

class DetailController extends PropertyDetailsController {
  DetailController(super.propertyId, this.value);
  final PropertyDetailsState value;
  int retries = 0;
  @override
  PropertyDetailsState build() => value;
  void replace(PropertyDetailsState value) => state = value;
  @override
  Future<void> refresh() async {
    retries++;
  }
}

class DetailSwipes extends SwipeHistory {
  int calls = 0;
  @override
  SwipeHistoryState build() => SwipeHistoryState();
  @override
  Future<bool> record(PropertyModel property, bool isLiked, {bool restored = false}) async {
    calls++;
    state = SwipeHistoryState(
      entries: {
        property.id: SwipeEntry(
          property: property,
          isLiked: isLiked,
          revision: calls,
          phase: SwipePhase.confirmed,
        ),
      },
    );
    return true;
  }
}

const fullProperty = PropertyModel(
  id: 100,
  title: 'Sunshine Villa',
  basePrice: 5000000,
  propertyType: PropertyType.house,
  purpose: PropertyPurpose.buy,
  description:
      'A beautiful villa with spacious rooms and a lovely garden. This property features three bedrooms, two bathrooms, and a large kitchen. Located in a prime area with excellent connectivity. The villa also has private parking and a garden area at the back. A long description has more information for prospective residents.',
  pricePerSqft: 4000,
  maintenanceCharges: 2000,
  bedrooms: 3,
  bathrooms: 2,
  balconies: 1,
  parkingSpaces: 2,
  areaSqft: 1200,
  ageOfProperty: 5,
  floorNumber: 2,
  totalFloors: 4,
  builderName: 'ABC Builders',
  mainImageUrl: '',
  city: 'Bangalore',
  locality: 'Indiranagar',
  features: ['Swimming Pool', 'Gym', 'Garden', 'Security'],
  amenities: [
    PropertyAmenity(id: 1, title: 'Swimming Pool'),
    PropertyAmenity(id: 2, title: 'Gym'),
  ],
  isAvailable: true,
  viewCount: 100,
  likeCount: 50,
  interestCount: 10,
);

/// The wire form of [fullProperty]: the keys the backend always sends, which the const fixture omits.
final fullPropertyJson = <String, dynamic>{
  ...fullProperty.toJson(),
  'owner_id': 7,
  'created_at': '2026-09-30T00:00:00Z',
  'updated_at': '2026-09-30T00:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late DetailController detail;
  late DetailSwipes swipes;
  late SeededVisitsController visits;
  late TestVisitScope scope;
  setUp(() async {
    database = await visitTestDatabase();
    AppConfig.initialize(
      overrides: {'API_BASE_URL': 'https://test.invalid', 'GOOGLE_PLACES_API_KEY': ''},
    );
    detail = DetailController(
      100,
      const PropertyDetailsState(property: fullProperty, phase: PropertyDetailPhase.content),
    );
    swipes = DetailSwipes();
    visits = SeededVisitsController(VisitsState(phase: VisitLoadPhase.content));
    scope = TestVisitScope(database);
  });
  tearDown(() async {
    await database.close();
    AppConfig.resetForTest();
  });
  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(800, 2600),
    double textScale = 1,
    Locale locale = const Locale('en', 'US'),
    PropertyModel? seed,
    ThemeData? theme,
    bool embedded = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpProviderApp(
      PropertyDetailsView(propertyId: 100, initialProperty: seed, embedded: embedded),
      textScale: textScale,
      locale: locale,
      theme: theme,
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        storageScopeProvider.overrideWith(() => scope),
        propertyDetailsProvider(100).overrideWith(() => detail),
        swipeHistoryProvider.overrideWith(() => swipes),
        visitsProvider.overrideWith(() => visits),
        pendingActionsProvider.overrideWith(SeededPendingActions.new),
      ],
    );
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('loading has back navigation and one loading state', (tester) async {
    detail = DetailController(100, const PropertyDetailsState());
    await pump(tester);
    expect(find.text('Property Details'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Sunshine Villa'), findsNothing);
  });
  testWidgets('typed failure displays safe localized retry', (tester) async {
    detail = DetailController(
      100,
      PropertyDetailsState(
        phase: PropertyDetailPhase.failed,
        failure: ServerException('SECRET server body', statusCode: 503),
      ),
    );
    await pump(tester);
    expect(find.textContaining('SECRET'), findsNothing);
    expect(find.text('Something went wrong on our side'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(detail.retries, 1);
  });
  testWidgets('missing listing shows the not-found scene without retry', (tester) async {
    detail = DetailController(
      100,
      PropertyDetailsState(phase: PropertyDetailPhase.failed, failure: NotFoundException('gone')),
    );
    await pump(tester);
    expect(find.byType(PaperVignette), findsOneWidget);
    expect(find.text('We could not find this'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.byTooltip('Back'), findsOneWidget);
  });
  for (final state in [
    const PropertyDetailsState(),
    PropertyDetailsState(phase: PropertyDetailPhase.failed, failure: NetworkException('x')),
    const PropertyDetailsState(property: fullProperty, phase: PropertyDetailPhase.content),
  ]) {
    testWidgets('embedded pane has no app bar or back button: ${state.phase.name}', (tester) async {
      detail = DetailController(100, state);
      await pump(tester, embedded: true);
      // Content keeps its photo header; only loading and failure drop the bar.
      if (state.property == null) expect(find.byType(AppBar), findsNothing);
      expect(find.byTooltip('Back'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('embedded pane keeps the section nav and the booking bar', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, embedded: true, size: const Size(480, 900));
    expect(find.text('Schedule Visit'), findsOneWidget);
    await tester.tap(find.text('Specs'));
    await tester.pumpAndSettle();
    expect(find.text('Property Information'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Specs')),
      isSemantics(label: 'Specs', isButton: true, isSelected: true, hasTapAction: true),
    );
    semantics.dispose();
  });
  group('gallery hero', () {
    final withPhoto = PropertyModel.fromJson({
      ...fullPropertyJson,
      'main_image_url': 'https://example.com/photo.jpg',
    });
    Finder heroOf(int id) =>
        find.byWidgetPredicate((w) => w is Hero && w.tag == propertyPhotoHeroTag(id));
    setUp(() {
      detail = DetailController(
        100,
        PropertyDetailsState(property: withPhoto, phase: PropertyDetailPhase.content),
      );
    });

    testWidgets('the photo carries the listing tag; an embedded pane has none', (tester) async {
      await pump(tester, size: const Size(390, 844));
      expect(heroOf(100), findsOneWidget);
      await pump(tester, size: const Size(390, 844), embedded: true);
      expect(heroOf(100), findsNothing);
    });

    testWidgets('a listing photo flies into the details photo and back', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpProviderApp(
        Builder(
          builder: (context) => Scaffold(
            body: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PropertyDetailsView(propertyId: 100)),
              ),
              child: Hero(
                tag: propertyPhotoHeroTag(100),
                child: const SizedBox(width: 200, height: 120, child: Text('Open')),
              ),
            ),
          ),
        ),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          storageScopeProvider.overrideWith(() => scope),
          propertyDetailsProvider(100).overrideWith(() => detail),
          swipeHistoryProvider.overrideWith(() => swipes),
          visitsProvider.overrideWith(() => visits),
          pendingActionsProvider.overrideWith(SeededPendingActions.new),
        ],
      );
      await tester.tap(find.text('Open'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('qa.property_details.screen')), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('collapsed, the bar is the page tone with ink icons and the name', (tester) async {
      await pump(tester, size: const Size(390, 844));
      Color backColour() => tester
          .widget<PaperIcon>(
            find.descendant(of: find.byTooltip('Back'), matching: find.byType(PaperIcon)),
          )
          .color!;
      expect(backColour(), photoInk);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pump(const Duration(seconds: 1));
      expect(backColour(), const AppPalette(isDark: false).textPrimary);
      expect(tester.takeException(), isNull);
    });
  });
  testWidgets('agent row shows the name and Call only with a number', (tester) async {
    PropertyModel withAgent(String? number) => PropertyModel.fromJson({
      ...fullPropertyJson,
      'agent': {'id': 3, 'name': 'Asha Verma', 'contact_number': number},
    });
    detail = DetailController(
      100,
      PropertyDetailsState(
        property: withAgent('+919810000000'),
        phase: PropertyDetailPhase.content,
      ),
    );
    await pump(tester);
    expect(find.text('Listed by'), findsOneWidget);
    expect(find.text('Asha Verma'), findsOneWidget);
    expect(find.byKey(const ValueKey('qa.property_details.agent_call')), findsOneWidget);
    detail.replace(
      PropertyDetailsState(property: withAgent(null), phase: PropertyDetailPhase.content),
    );
    await tester.pump();
    expect(find.text('Asha Verma'), findsOneWidget);
    expect(find.byKey(const ValueKey('qa.property_details.agent_call')), findsNothing);
  });
  testWidgets('without an agent there is no Listed by row', (tester) async {
    await pump(tester);
    expect(find.text('Listed by'), findsNothing);
  });
  testWidgets('stale cached details say so quietly', (tester) async {
    detail = DetailController(
      100,
      const PropertyDetailsState(
        property: fullProperty,
        phase: PropertyDetailPhase.content,
        stale: true,
      ),
    );
    await pump(tester);
    expect(find.text('Saved property details. Refresh to check availability.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('seed is visible during authoritative fetch and updates after fetch', (tester) async {
    detail = DetailController(100, const PropertyDetailsState());
    await pump(tester, seed: fullProperty);
    expect(find.text('Sunshine Villa'), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    detail.replace(
      PropertyDetailsState(
        property: PropertyModel.fromJson({...fullPropertyJson, 'title': 'New title'}),
        phase: PropertyDetailPhase.content,
      ),
    );
    await tester.pump();
    expect(find.text('New title'), findsWidgets);
    expect(find.text('Sunshine Villa'), findsNothing);
  });
  testWidgets('seed for a different ID is rejected', (tester) async {
    detail = DetailController(100, const PropertyDetailsState());
    await pump(tester, seed: propertyFixture(id: 200));
    expect(find.text('Test Property 200'), findsNothing);
  });
  testWidgets('account change removes original summary seed', (tester) async {
    detail = DetailController(100, const PropertyDetailsState());
    await pump(tester, seed: fullProperty);
    scope.change('account-b');
    await tester.pump();
    expect(find.text('Sunshine Villa'), findsNothing);
  });
  testWidgets('deleted listing cannot retain summary booking action', (tester) async {
    detail = DetailController(
      100,
      PropertyDetailsState(
        phase: PropertyDetailPhase.failed,
        failure: NotFoundException('private'),
      ),
    );
    await pump(tester, seed: fullProperty);
    expect(find.text('Sunshine Villa'), findsNothing);
    expect(find.text('Schedule Visit'), findsNothing);
  });
  testWidgets('refresh failure keeps listing and displays retry', (tester) async {
    detail = DetailController(
      100,
      PropertyDetailsState(
        property: fullProperty,
        phase: PropertyDetailPhase.content,
        stale: true,
        failure: NetworkException('SECRET'),
      ),
    );
    await pump(tester);
    expect(find.text('Sunshine Villa'), findsWidgets);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('SECRET'), findsNothing);
  });
  for (final label in [
    'Description',
    'Highlights',
    'Amenities',
    'Builder Information',
    'Property Information',
    'Pricing Details',
    'ABC Builders',
    '₹4,000',
    '₹2,000',
  ]) {
    testWidgets('listing preserves $label content', (tester) async {
      await pump(tester);
      expect(find.text(label), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('description expands and collapses', (tester) async {
    await pump(tester, size: const Size(430, 2200));
    await tester.tap(find.text('Read more'));
    await tester.pump();
    expect(find.text('Read less'), findsOneWidget);
    await tester.ensureVisible(find.text('Read less'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read less'));
    await tester.pump();
    expect(find.text('Read more'), findsOneWidget);
  });
  testWidgets('favourite uses shared intent and updates icon', (tester) async {
    await pump(tester);
    await tester.tap(findKnife(KnifeIcon.heart));
    await tester.pump();
    expect(swipes.calls, 1);
    expect(findKnife(KnifeIcon.heartSolid), findsOneWidget);
    await tester.tap(findKnife(KnifeIcon.heartSolid));
    await tester.pump();
    expect(swipes.calls, 2);
    expect(findKnife(KnifeIcon.heart), findsOneWidget);
  });
  testWidgets('confirmed appointment replaces schedule action', (tester) async {
    visits = SeededVisitsController(
      VisitsState(phase: VisitLoadPhase.content, visits: [visitFixture()]),
    );
    await pump(tester);
    expect(find.text('Visit Scheduled'), findsOneWidget);
    expect(find.text('Schedule Visit'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('schedule opens local booking form with property', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Schedule Visit'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final size in [const Size(390, 844), const Size(1400, 900)]) {
    testWidgets('responsive details with large text at $size have no overflow', (tester) async {
      await pump(tester, size: size, textScale: 2);
      expect(tester.takeException(), isNull);
      for (final label in ['Back', 'Share']) {
        final button = find.byTooltip(label);
        expect(button, findsOneWidget);
        final target = tester.getSize(button);
        expect(target.width, greaterThanOrEqualTo(48));
        expect(target.height, greaterThanOrEqualTo(48));
      }
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1400));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  }
  for (final state in [
    const PropertyDetailsState(),
    PropertyDetailsState(phase: PropertyDetailPhase.failed, failure: NetworkException('x')),
    PropertyDetailsState(
      property: PropertyModel.fromJson({
        ...fullPropertyJson,
        'agent': {'id': 3, 'name': 'Asha Verma', 'contact_number': '+919810000000'},
        'latitude': 12.97,
        'longitude': 77.59,
        'video_tour_url': 'https://example.com/tour.mp4',
        'virtual_tour_url': 'https://kuula.co/share/example',
      }),
      phase: PropertyDetailPhase.content,
      stale: true,
      failure: NetworkException('x'),
    ),
  ]) {
    testWidgets('320 px, Hindi, 2x text, dark theme: ${state.phase.name} fits', (tester) async {
      detail = DetailController(100, state);
      await pump(
        tester,
        size: const Size(320, 640),
        textScale: 2,
        locale: const Locale('hi', 'IN'),
        theme: AppDesignTheme.dark(),
      );
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 12 && state.property != null; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('Hindi and dark theme retain readable controls', (tester) async {
    await pump(tester, locale: const Locale('hi', 'IN'), theme: ThemeData.dark());
    expect(find.text('Sunshine Villa'), findsWidgets);
    expect(findKnife(KnifeIcon.share), findsOneWidget);
    expect(find.byTooltip('वापस'), findsOneWidget);
    expect(find.byTooltip('साझा करें'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
