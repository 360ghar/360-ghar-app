import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/widgets/common/robust_network_image.dart';

import '../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('renders error widget for an empty URL', (tester) async {
    await pumpWidget(
      tester,
      const RobustNetworkImage(imageUrl: '', width: 200, height: 200),
    );

    // No valid URL → default error widget with home icon.
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    // The "Property Image" label is shown when width > 100.
    expect(find.text('Property Image'), findsOneWidget);
    // CachedNetworkImage is NOT rendered for invalid URLs.
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('renders error widget for a null-equivalent invalid URL', (tester) async {
    await pumpWidget(
      tester,
      const RobustNetworkImage(imageUrl: 'not-a-url', width: 80, height: 80),
    );

    // Invalid URL → error widget (home icon).
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('renders CachedNetworkImage for a valid http URL', (tester) async {
    await pumpWidget(
      tester,
      const RobustNetworkImage(
        imageUrl: 'https://example.com/image.jpg',
        width: 200,
        height: 200,
      ),
    );

    // A valid URL produces a CachedNetworkImage widget.
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('renders CachedNetworkImage for a valid https URL', (tester) async {
    await pumpWidget(
      tester,
      const RobustNetworkImage(
        imageUrl: 'https://cdn.example.com/photo.png',
        width: 100,
        height: 100,
      ),
    );

    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('shows loading placeholder while image loads', (tester) async {
    await pumpWidget(
      tester,
      const RobustNetworkImage(
        imageUrl: 'https://example.com/image.jpg',
        width: 200,
        height: 200,
      ),
    );

    // The default placeholder contains a CircularProgressIndicator.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('uses custom placeholder when provided', (tester) async {
    await pumpWidget(
      tester,
      RobustNetworkImage(
        imageUrl: 'https://example.com/image.jpg',
        width: 200,
        height: 200,
        placeholder: const Text('Custom Placeholder'),
      ),
    );

    expect(find.text('Custom Placeholder'), findsOneWidget);
  });

  testWidgets('uses custom error widget when provided for invalid URL', (tester) async {
    await pumpWidget(
      tester,
      RobustNetworkImage(
        imageUrl: '',
        width: 200,
        height: 200,
        errorWidget: const Text('Custom Error'),
      ),
    );

    expect(find.text('Custom Error'), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
  });

  testWidgets('applies ClipRRect when borderRadius is provided', (tester) async {
    await pumpWidget(
      tester,
      const RobustNetworkImage(
        imageUrl: 'https://example.com/image.jpg',
        width: 200,
        height: 200,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    );

    expect(find.byType(ClipRRect), findsOneWidget);
  });

  testWidgets('applies ClipRRect for invalid URL with borderRadius', (tester) async {
    await pumpWidget(
      tester,
      const RobustNetworkImage(
        imageUrl: '',
        width: 200,
        height: 200,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    );

    expect(find.byType(ClipRRect), findsOneWidget);
  });

  group('ImageLoadingService', () {
    test('isValidUrl returns true for valid http(s) URLs', () {
      expect(ImageLoadingService.isValidUrl('https://example.com/img.jpg'), isTrue);
      expect(ImageLoadingService.isValidUrl('http://example.com/img.jpg'), isTrue);
    });

    test('isValidUrl returns false for invalid URLs', () {
      expect(ImageLoadingService.isValidUrl(''), isFalse);
      expect(ImageLoadingService.isValidUrl('not-a-url'), isFalse);
      expect(ImageLoadingService.isValidUrl('ftp://example.com/img.jpg'), isFalse);
    });

    test('getValidImageUrl returns null for null or empty input', () {
      expect(ImageLoadingService.getValidImageUrl(null), isNull);
      expect(ImageLoadingService.getValidImageUrl(''), isNull);
    });

    test('getValidImageUrl returns the URL when valid', () {
      expect(
        ImageLoadingService.getValidImageUrl('https://example.com/img.jpg'),
        'https://example.com/img.jpg',
      );
    });
  });
}
