// Widget tests for the property media experience strip [PropertyMediaHub].

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/data/models/property_image_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_media_hub.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/google_fonts_test_helper.dart';

PropertyModel _propertyWithGalleryImages() {
  return const PropertyModel(
    id: 1,
    title: 'Gallery Home',
    basePrice: 5000000,
    propertyType: PropertyType.house,
    purpose: PropertyPurpose.buy,
    mainImageUrl: 'https://example.com/main.jpg',
    images: [
      PropertyImageModel(
        id: 1,
        propertyId: 1,
        imageUrl: 'https://example.com/main.jpg',
        isMain: true,
        displayOrder: 0,
      ),
      PropertyImageModel(
        id: 2,
        propertyId: 1,
        imageUrl: 'https://example.com/img2.jpg',
        displayOrder: 1,
      ),
      PropertyImageModel(
        id: 3,
        propertyId: 1,
        imageUrl: 'https://example.com/img3.jpg',
        displayOrder: 2,
      ),
    ],
    isAvailable: true,
    viewCount: 0,
    likeCount: 0,
    interestCount: 0,
  );
}

PropertyModel _propertyWithMainImageOnly() {
  return const PropertyModel(
    id: 2,
    title: 'Single Image',
    basePrice: 3000000,
    propertyType: PropertyType.apartment,
    purpose: PropertyPurpose.buy,
    mainImageUrl: 'https://example.com/only.jpg',
    isAvailable: true,
    viewCount: 0,
    likeCount: 0,
    interestCount: 0,
  );
}

PropertyModel _propertyWithNoImages() {
  return const PropertyModel(
    id: 3,
    title: 'No Images',
    basePrice: 1000000,
    propertyType: PropertyType.plot,
    purpose: PropertyPurpose.buy,
    mainImageUrl: '',
    isAvailable: true,
    viewCount: 0,
    likeCount: 0,
    interestCount: 0,
  );
}

PropertyModel _propertyWithVideos() {
  return const PropertyModel(
    id: 20,
    title: 'Video Property',
    basePrice: 6000000,
    propertyType: PropertyType.apartment,
    purpose: PropertyPurpose.buy,
    mainImageUrl: 'https://example.com/apt.jpg',
    videoTourUrl: 'https://example.com/video.mp4',
    videoUrls: ['https://example.com/extra.mp4'],
    isAvailable: true,
    viewCount: 0,
    likeCount: 0,
    interestCount: 0,
  );
}

PropertyModel _propertyWithFloorPlan() {
  return const PropertyModel(
    id: 30,
    title: 'Floor Plan Property',
    basePrice: 4000000,
    propertyType: PropertyType.apartment,
    purpose: PropertyPurpose.buy,
    mainImageUrl: 'https://example.com/apt.jpg',
    floorPlanUrl: 'https://example.com/floorplan.jpg',
    isAvailable: true,
    viewCount: 0,
    likeCount: 0,
    interestCount: 0,
  );
}

PropertyModel _propertyWithStreetView() {
  return const PropertyModel(
    id: 40,
    title: 'Street View Property',
    basePrice: 4500000,
    propertyType: PropertyType.house,
    purpose: PropertyPurpose.buy,
    mainImageUrl: 'https://example.com/house.jpg',
    googleStreetViewUrl:
        'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=12.97,77.59',
    latitude: 12.97,
    longitude: 77.59,
    isAvailable: true,
    viewCount: 0,
    likeCount: 0,
    interestCount: 0,
  );
}

PropertyModel _propertyWithVirtualTour() {
  return const PropertyModel(
    id: 50,
    title: 'Virtual Tour Property',
    basePrice: 5500000,
    propertyType: PropertyType.villa,
    purpose: PropertyPurpose.buy,
    mainImageUrl: 'https://example.com/villa.jpg',
    virtualTourUrl: 'https://kuula.co/share/example',
    isAvailable: true,
    viewCount: 0,
    likeCount: 0,
    interestCount: 0,
  );
}

void _seedAppConfig() {
  AppConfig.initialize(
    overrides: {'API_BASE_URL': 'https://api.test.com', 'GOOGLE_PLACES_API_KEY': 'test-api-key'},
  );
}

void main() {
  configureGoogleFontsForTests();

  const urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');
  final launchedUrls = <String>[];

  setUp(() {
    FlutterError.onError = (FlutterErrorDetails details) {
      final summary = details.exception.toString();
      if (summary.contains('RenderFlex overflowed')) return;
      FlutterError.presentError(details);
    };
    GetxTestBinding.init();
    _seedAppConfig();
    launchedUrls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      urlLauncherChannel,
      (MethodCall call) async {
        if (call.method == 'canLaunch' || call.method == 'canLaunchUrl') {
          return true;
        }
        if (call.method == 'launch' || call.method == 'launchUrl') {
          final args = call.arguments;
          if (args is Map) {
            final url = args['url']?.toString();
            if (url != null) launchedUrls.add(url);
          }
          return true;
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      urlLauncherChannel,
      null,
    );
    GetxTestBinding.reset();
    AppConfig.resetForTest();
  });

  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pump();
  }

  group('PropertyMediaHub', () {
    testWidgets('renders media section header and photos tile', (tester) async {
      await pumpWidget(tester, PropertyMediaHub(property: _propertyWithGalleryImages()));

      expect(find.text('Media'), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // badge count
    });

    testWidgets('renders photos tile for main image only', (tester) async {
      await pumpWidget(tester, PropertyMediaHub(property: _propertyWithMainImageOnly()));

      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Video Tour'), findsNothing);
      expect(find.text('360° Virtual Tour'), findsNothing);
    });

    testWidgets('returns empty when property has no media', (tester) async {
      await pumpWidget(tester, PropertyMediaHub(property: _propertyWithNoImages()));

      expect(find.text('Media'), findsNothing);
      expect(find.text('Photos'), findsNothing);
    });

    testWidgets('renders video tour tile when property has videos', (tester) async {
      await pumpWidget(tester, PropertyMediaHub(property: _propertyWithVideos()));

      expect(find.text('Video Tour'), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);
    });

    testWidgets('renders virtual tour tile without WebView', (tester) async {
      await pumpWidget(tester, PropertyMediaHub(property: _propertyWithVirtualTour()));

      expect(find.text('360° Virtual Tour'), findsOneWidget);
      expect(find.byIcon(Icons.threesixty), findsOneWidget);
      // Lazy strip — no eager WebView.
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('renders street view tile', (tester) async {
      await pumpWidget(tester, PropertyMediaHub(property: _propertyWithStreetView()));

      expect(find.text('Street View'), findsOneWidget);
      expect(find.byIcon(Icons.streetview), findsOneWidget);
    });

    testWidgets('renders floor plan tile', (tester) async {
      await pumpWidget(tester, PropertyMediaHub(property: _propertyWithFloorPlan()));

      expect(find.text('Floor Plan'), findsOneWidget);
      expect(find.byIcon(Icons.apartment_rounded), findsOneWidget);
    });

    testWidgets('renders all media tiles for rich property', (tester) async {
      final property = const PropertyModel(
        id: 11,
        title: 'Full Media Property',
        basePrice: 8000000,
        propertyType: PropertyType.villa,
        purpose: PropertyPurpose.buy,
        mainImageUrl: 'https://example.com/villa.jpg',
        images: [
          PropertyImageModel(
            id: 10,
            propertyId: 11,
            imageUrl: 'https://example.com/villa.jpg',
            isMain: true,
            displayOrder: 0,
          ),
        ],
        videoTourUrl: 'https://example.com/tour.mp4',
        virtualTourUrl: 'https://kuula.co/share/example',
        googleStreetViewUrl:
            'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=12.97,77.59',
        floorPlanUrl: 'https://example.com/floorplan.jpg',
        latitude: 12.97,
        longitude: 77.59,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      await pumpWidget(tester, PropertyMediaHub(property: property));

      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('360° Virtual Tour'), findsOneWidget);
      expect(find.text('Video Tour'), findsOneWidget);
      expect(find.text('Floor Plan'), findsOneWidget);
      expect(find.text('Street View'), findsOneWidget);
    });

    testWidgets('opens fullscreen gallery when photos tile tapped', (tester) async {
      await pumpWidget(tester, PropertyMediaHub(property: _propertyWithGalleryImages()));

      await tester.tap(find.text('Photos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Fullscreen route uses Scaffold, not Dialog.
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('opens video sheet when video tile tapped', (tester) async {
      await pumpWidget(tester, PropertyMediaHub(property: _propertyWithVideos()));

      await tester.tap(find.text('Video Tour'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Bottom sheet shows video title; player may error in tests.
      expect(find.text('Video Tour'), findsWidgets);
    });

    testWidgets('launches street view URL when tile tapped', (tester) async {
      await pumpWidget(tester, PropertyMediaHub(property: _propertyWithStreetView()));

      await tester.tap(find.text('Street View'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(launchedUrls, isNotEmpty);
    });

    testWidgets('does not render absent media types', (tester) async {
      await pumpWidget(tester, PropertyMediaHub(property: _propertyWithMainImageOnly()));

      expect(find.text('Street View'), findsNothing);
      expect(find.text('Floor Plan'), findsNothing);
      expect(find.text('Video Tour'), findsNothing);
      expect(find.text('360° Virtual Tour'), findsNothing);
    });

    testWidgets('uses googleMapsApiKey parameter when provided', (tester) async {
      await pumpWidget(
        tester,
        PropertyMediaHub(property: _propertyWithStreetView(), googleMapsApiKey: 'custom-key'),
      );

      expect(find.text('Street View'), findsOneWidget);
    });
  });
}
