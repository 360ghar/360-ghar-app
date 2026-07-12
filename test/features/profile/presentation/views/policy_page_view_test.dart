import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/static_page_model.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/profile/data/static_page_repository.dart';
import 'package:ghar360/features/profile/presentation/views/policy_page_view.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

class MockStaticPageRepository extends GetxServiceMock
    implements StaticPageRepository {}

void main() {
  late MockStaticPageRepository repository;

  setUp(() {
    GetxTestBinding.init();
    repository = MockStaticPageRepository();
    GetxTestBinding.bind()..register<StaticPageRepository>(repository);
  });

  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: PolicyPageView(
          uniqueName: 'privacy_policy',
          titleText: 'Privacy Policy',
        ),
      ),
    );
  }

  testWidgets('shows loading indicator initially', (tester) async {
    final completer = Completer<StaticPageModel>();
    when(() => repository.fetchPublicPage(any()))
        .thenAnswer((_) => completer.future);

    await pumpView(tester);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Complete the future so the test can clean up.
    completer.complete(const StaticPageModel(title: 'Privacy', content: 'content'));
    await tester.pumpAndSettle();
  });

  testWidgets('renders markdown content on successful load', (tester) async {
    when(() => repository.fetchPublicPage('privacy_policy')).thenAnswer(
      (_) async => const StaticPageModel(
        title: 'Privacy Policy',
        content: '# Privacy Policy\n\nThis is our privacy policy.',
      ),
    );

    await pumpView(tester);
    await tester.pumpAndSettle();

    expect(find.text('Privacy Policy'), findsWidgets);
    expect(find.textContaining('This is our privacy policy'), findsOneWidget);
  });

  testWidgets('shows content unavailable when page content is empty', (tester) async {
    when(() => repository.fetchPublicPage(any())).thenAnswer(
      (_) async => const StaticPageModel(title: 'Privacy', content: '   '),
    );

    await pumpView(tester);
    await tester.pumpAndSettle();

    expect(find.text('No content available.'), findsOneWidget);
  });

  testWidgets('shows error message on load failure', (tester) async {
    when(() => repository.fetchPublicPage(any()))
        .thenThrow(Exception('Network error'));

    await pumpView(tester);
    await tester.pumpAndSettle();

    expect(find.text('Failed to load content'), findsOneWidget);
  });

  testWidgets('shows no content when markdownContent is null after load', (tester) async {
    when(() => repository.fetchPublicPage(any())).thenAnswer(
      (_) async => const StaticPageModel(title: 'Privacy', content: ''),
    );

    await pumpView(tester);
    await tester.pumpAndSettle();

    // Empty content -> content_unavailable message
    expect(find.text('No content available.'), findsOneWidget);
  });

  testWidgets('renders app bar with provided title', (tester) async {
    when(() => repository.fetchPublicPage(any()))
        .thenAnswer((_) async => const StaticPageModel(title: 'Privacy', content: 'content'));

    await pumpView(tester);
    await tester.pumpAndSettle();

    expect(find.text('Privacy Policy'), findsWidgets);
  });

  testWidgets('renders markdown with headings and paragraphs', (tester) async {
    when(() => repository.fetchPublicPage('privacy_policy')).thenAnswer(
      (_) async => const StaticPageModel(
        title: 'Privacy',
        content: '# Heading 1\n\nSome paragraph text.\n\n## Heading 2',
      ),
    );

    await pumpView(tester);
    await tester.pumpAndSettle();

    expect(find.text('Heading 1'), findsOneWidget);
    expect(find.text('Heading 2'), findsOneWidget);
    expect(find.textContaining('Some paragraph text'), findsOneWidget);
  });
}
