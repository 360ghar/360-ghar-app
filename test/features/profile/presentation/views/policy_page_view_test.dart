import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ghar360/core/data/models/static_page_model.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/features/profile/presentation/views/policy_page_view.dart';
import '../../../../helpers/profile_test_harness.dart';
import '../../../../helpers/visits_test_support.dart';

void main() {
  late ProfileHarness h;
  late MockStaticPageRepository repository;
  setUp(() {
    h = ProfileHarness();
    repository = h.pages;
  });
  tearDown(() => h.close());
  Future<void> pumpView(WidgetTester tester) => h.pump(
    tester,
    const PolicyPageView(uniqueName: 'privacy_policy', titleText: 'Privacy Policy'),
  );
  testWidgets('shows loading indicator initially', (tester) async {
    final completer = Completer<StaticPageModel>();
    when(() => repository.fetchPublicPage(any())).thenAnswer((_) => completer.future);

    await pumpView(tester);
    await tester.pump();

    expect(find.byType(Skeleton), findsOneWidget);

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
    when(
      () => repository.fetchPublicPage(any()),
    ).thenAnswer((_) async => const StaticPageModel(title: 'Privacy', content: '   '));

    await pumpView(tester);
    await tester.pumpAndSettle();

    expect(find.text('No content available.'), findsOneWidget);
  });

  testWidgets('shows error message on load failure', (tester) async {
    when(() => repository.fetchPublicPage(any())).thenThrow(Exception('Network error'));

    await pumpView(tester);
    await tester.pumpAndSettle();

    expect(find.text('Failed to load content'), findsOneWidget);
  });

  testWidgets('shows no content when markdownContent is null after load', (tester) async {
    when(
      () => repository.fetchPublicPage(any()),
    ).thenAnswer((_) async => const StaticPageModel(title: 'Privacy', content: ''));

    await pumpView(tester);
    await tester.pumpAndSettle();

    // Empty content -> content_unavailable message
    expect(find.text('No content available.'), findsOneWidget);
  });

  testWidgets('renders app bar with provided title', (tester) async {
    when(
      () => repository.fetchPublicPage(any()),
    ).thenAnswer((_) async => const StaticPageModel(title: 'Privacy', content: 'content'));

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
  testWidgets('retry replaces failed policy request with content', (tester) async {
    when(() => repository.fetchPublicPage(any())).thenThrow(Exception('offline'));
    await pumpView(tester);
    await tester.pumpAndSettle();
    expect(find.text('Failed to load content'), findsOneWidget);
    when(
      () => repository.fetchPublicPage(any()),
    ).thenAnswer((_) async => const StaticPageModel(title: 'Policy', content: 'Recovered policy'));
    await tester.ensureVisible(find.text(tr('retry')));
    await tester.pump();
    await tester.tap(find.text(tr('retry')));
    await tester.pumpAndSettle();
    expect(find.text('Recovered policy'), findsOneWidget);
    verify(() => repository.fetchPublicPage('privacy_policy')).called(2);
  });
  group('stale-while-revalidate cache', () {
    late AppDatabase database;
    late MockStaticPageRepository pages;
    late ProviderContainer container;
    var now = DateTime(2026, 9, 30, 12);
    setUp(() async {
      database = await visitTestDatabase();
      pages = MockStaticPageRepository();
      now = DateTime(2026, 9, 30, 12);
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          storageScopeProvider.overrideWith(() => TestVisitScope(database)),
          staticPageRepositoryProvider.overrideWithValue(pages),
          staticPageClockProvider.overrideWithValue(() => now),
        ],
      );
    });
    tearDown(() async {
      container.dispose();
      await database.close();
    });
    Future<void> seed(String content, {required Duration freshFor}) => database.writeCache(
      scope: container.read(storageScopeProvider),
      key: 'static_page:privacy_policy',
      value: {
        'title': 'Privacy',
        'content': content,
        'format': 'markdown',
        'unique_name': 'privacy_policy',
        'updated_at': '2026-09-30T10:15:02Z',
      },
      freshUntil: now.add(freshFor),
      expiresAt: now.add(const Duration(days: 30)),
    );
    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: PolicyPageView(uniqueName: 'privacy_policy', titleText: 'Privacy Policy'),
          ),
        ),
      );
    }

    testWidgets('a fresh cached page shows at once with no skeleton or request', (tester) async {
      await tester.runAsync(() => seed('Cached policy', freshFor: const Duration(hours: 1)));
      await pumpPage(tester);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(find.text('Cached policy'), findsOneWidget);
      expect(find.byType(Skeleton), findsNothing);
      verifyNever(() => pages.fetchPublicPage(any()));
    });

    testWidgets('a stale cached page shows while the refresh replaces it', (tester) async {
      await tester.runAsync(() => seed('Old policy', freshFor: -const Duration(hours: 1)));
      final response = Completer<StaticPageModel>();
      when(() => pages.fetchPublicPage('privacy_policy')).thenAnswer((_) => response.future);
      await pumpPage(tester);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(find.text('Old policy'), findsOneWidget);
      expect(find.byType(Skeleton), findsNothing);
      response.complete(const StaticPageModel(title: 'Privacy', content: 'New policy'));
      await tester.pump();
      expect(find.text('New policy'), findsOneWidget);
      final cached = await tester.runAsync(
        () => database.readCache(
          scope: container.read(storageScopeProvider),
          key: 'static_page:privacy_policy',
        ),
      );
      expect((cached!.value! as Map)['content'], 'New policy');
    });

    testWidgets('a failed refresh keeps the cached page and offers retry', (tester) async {
      await tester.runAsync(() => seed('Old policy', freshFor: -const Duration(hours: 1)));
      when(() => pages.fetchPublicPage(any())).thenThrow(NetworkException('offline'));
      await pumpPage(tester);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(find.text('Old policy'), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.content.retry')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.state.error.action')), findsNothing);
    });
  });
}
