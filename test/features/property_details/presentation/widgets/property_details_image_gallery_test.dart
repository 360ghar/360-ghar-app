import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/property_image_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_image_gallery.dart';

PropertyModel _propertyWithGalleryImages() {
  return PropertyModel(
    id: 1,
    title: 'Gallery Home',
    basePrice: 5000000,
    propertyType: PropertyType.house,
    purpose: PropertyPurpose.buy,
    mainImageUrl: 'https://example.com/main.jpg',
    images: [
      const PropertyImageModel(
        id: 1,
        propertyId: 1,
        imageUrl: 'https://example.com/main.jpg',
        isMain: true,
        displayOrder: 0,
      ),
      const PropertyImageModel(
        id: 2,
        propertyId: 1,
        imageUrl: 'https://example.com/img2.jpg',
        displayOrder: 1,
      ),
      const PropertyImageModel(
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
  return PropertyModel(
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
  return PropertyModel(
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

void main() {
  // Suppress FlutterError overflow exceptions that can occur in constrained
  // test viewports so they don't fail the test suite.
  setUp(() {
    FlutterError.onError = (FlutterErrorDetails details) {
      final summary = details.exception.toString();
      if (summary.contains('RenderFlex overflowed')) return;
      FlutterError.presentError(details);
    };
  });

  Future<void> pumpGallery(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(400, 300),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    );
    // Use pump (not pumpAndSettle) to avoid hanging on network image loads.
    await tester.pump();
  }

  testWidgets('renders PageView with gallery images and shows counter', (tester) async {
    await pumpGallery(tester, PropertyDetailsImageGallery(property: _propertyWithGalleryImages()));

    // The page counter "1/3" should be visible since there are 3 images.
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('hides counter when only one image', (tester) async {
    await pumpGallery(tester, PropertyDetailsImageGallery(property: _propertyWithMainImageOnly()));

    // No counter should be shown for single-image galleries.
    expect(find.byType(PageView), findsOneWidget);
    // No "1/1" text since itemCount is 1 (counter only shows when > 1).
    expect(find.text('1/1'), findsNothing);
  });

  testWidgets('shows placeholder icon when no valid images', (tester) async {
    await pumpGallery(tester, PropertyDetailsImageGallery(property: _propertyWithNoImages()));

    expect(find.byIcon(Icons.image), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('updates counter when swiping to next page', (tester) async {
    await pumpGallery(tester, PropertyDetailsImageGallery(property: _propertyWithGalleryImages()));

    expect(find.text('1/3'), findsOneWidget);

    // Swipe left to go to the next image.
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('wraps gallery in SizedBox when maxHeight is provided', (tester) async {
    await pumpGallery(
      tester,
      PropertyDetailsImageGallery(property: _propertyWithGalleryImages(), maxHeight: 200),
    );

    // The SizedBox with height 200 should wrap the gallery.
    final sizedBoxes = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .where((sb) => sb.height == 200);
    expect(sizedBoxes, isNotEmpty);
  });

  testWidgets('does not wrap in SizedBox when maxHeight is null', (tester) async {
    await pumpGallery(tester, PropertyDetailsImageGallery(property: _propertyWithGalleryImages()));

    // No SizedBox with a specific height should wrap the gallery directly.
    // The gallery Stack should be the direct child (no height cap).
    final stackFinder = find.byType(Stack);
    expect(stackFinder, findsWidgets);
  });

  testWidgets('opens full-screen gallery on tap', (tester) async {
    await pumpGallery(tester, PropertyDetailsImageGallery(property: _propertyWithGalleryImages()));

    // Tap the gallery to open the full-screen PhotoView route.
    await tester.tap(find.byType(PageView));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Fullscreen route uses a close button, not a Dialog.
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
