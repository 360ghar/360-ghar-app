@TestOn('mac-os')
library;

// Property details golden: content in {light, dark} × {(390, en, 1x), (320, hi, 2x)}, and the
// collapsed header (scrolled, 390 × 844, en) in light and dark.
// The fixture photo is served from test/fixtures/images so the photo header is real.

import 'dart:io';

import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/providers/pending_actions_provider.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/image_cache_service.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import 'package:ghar360/features/property_details/presentation/controllers/property_details_controller.dart';
import 'package:ghar360/features/property_details/presentation/views/property_details_view.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';

import '../helpers/image_test_cache.dart';
import '../helpers/layout_variants.dart';
import '../helpers/load_app_fonts.dart';
import '../helpers/visits_test_support.dart';

class _Detail extends PropertyDetailsController {
  _Detail() : super(_home.id);
  @override
  PropertyDetailsState build() =>
      const PropertyDetailsState(property: _home, phase: PropertyDetailPhase.content);
}

class _Swipes extends SwipeHistory {
  @override
  SwipeHistoryState build() => SwipeHistoryState();
}

const _home = PropertyModel(
  id: 57,
  title: 'Garden Court Residence',
  basePrice: 8500000,
  propertyType: PropertyType.apartment,
  purpose: PropertyPurpose.buy,
  description:
      'A corner flat on the fourth floor with two balconies and morning light. '
      'Five minutes from the Sector 55-56 Rapid Metro station.',
  bedrooms: 3,
  bathrooms: 2,
  balconies: 2,
  parkingSpaces: 1,
  areaSqft: 1450,
  floorNumber: 4,
  totalFloors: 12,
  city: 'Gurugram',
  locality: 'Sector 57',
  fullAddress: 'Sector 57, Gurugram, Haryana',
  mainImageUrl: 'https://visual-fixture.invalid/details.jpg',
  builderName: 'Parkside Estates',
  features: ['Corner unit', 'Two balconies', 'Covered parking'],
  amenities: [
    PropertyAmenity(id: 1, title: 'Swimming Pool', icon: 'pool'),
    PropertyAmenity(id: 2, title: 'Power Backup', icon: 'battery'),
    PropertyAmenity(id: 3, title: 'Gym', icon: 'fitness'),
  ],
  agent: PropertyAgent(id: 4, name: 'Ravi Kumar', contactNumber: '+919811111111'),
  isAvailable: true,
  viewCount: 24,
  likeCount: 8,
  interestCount: 3,
);

void _case(
  String name, {
  required Size size,
  required bool dark,
  required bool compact,
  required bool collapsed,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  testWidgets(name, (tester) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppConfig.initialize(
      overrides: {'API_BASE_URL': 'https://test.invalid', 'GOOGLE_PLACES_API_KEY': ''},
    );
    addTearDown(AppConfig.resetForTest);
    final AppDatabase database = (await tester.runAsync(visitTestDatabase))!;
    final images = ImageTestCache()
      ..response = (url) => Stream.value(
        FileInfo(
          const LocalFileSystem().file(
            '${Directory.current.path}/test/fixtures/images/property_photo.jpg',
          ),
          FileSource.Cache,
          DateTime(2030),
          url,
        ),
      );
    final locale = compact ? const Locale('hi', 'IN') : const Locale('en', 'US');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(images.service),
          appDatabaseProvider.overrideWithValue(database),
          storageScopeProvider.overrideWith(() => TestVisitScope(database)),
          propertyDetailsProvider(_home.id).overrideWith(_Detail.new),
          swipeHistoryProvider.overrideWith(_Swipes.new),
          visitsProvider.overrideWith(
            () => SeededVisitsController(VisitsState(phase: VisitLoadPhase.content)),
          ),
          pendingActionsProvider.overrideWith(SeededPendingActions.new),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppDesignTheme.dark() : AppDesignTheme.light(),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: withInset(
              MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(compact ? 2 : 1)),
              padding,
            ),
            child: AppToastHost(child: child!),
          ),
          home: RepaintBoundary(
            key: const ValueKey('visual.screen'),
            child: PropertyDetailsView(propertyId: _home.id, initialProperty: _home),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await settleFixturePhotos(tester);
    if (collapsed) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('visual.screen')),
      matchesGoldenFile('goldens/$name.png'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(database.close);
  });
}

void main() {
  setUpAll(loadAppFonts);

  for (final dark in [false, true]) {
    for (final (compact, collapsed) in [(false, false), (true, false), (false, true)]) {
      final theme = dark ? 'dark' : 'light';
      final name = collapsed
          ? 'details_collapsed_${theme}_390_en_1x'
          : 'details_content_${theme}_${compact ? '320_hi_2x' : '390_en_1x'}';
      _case(
        name,
        size: Size(compact ? 320 : 390, collapsed ? 844 : 1400),
        dark: dark,
        compact: compact,
        collapsed: collapsed,
      );
    }
  }

  // Wide and Duo windows: content, light only.
  for (final v in layoutVariants) {
    _case(
      'details_content_light_${v.name}',
      size: v.size,
      dark: false,
      compact: false,
      collapsed: false,
      padding: v.padding,
    );
  }
}
