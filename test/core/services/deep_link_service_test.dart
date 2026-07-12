import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/services/deep_link_service.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  group('DeepLinkService.propertyDeepLinkPath', () {
    test('shared property links target the public details route', () {
      expect(DeepLinkService.propertyDeepLinkPath('123'), '/property/123');
    });

    test('handles numeric property ids', () {
      expect(DeepLinkService.propertyDeepLinkPath('42'), '/property/42');
      expect(DeepLinkService.propertyDeepLinkPath('0'), '/property/0');
    });

    test('handles string/slug property ids', () {
      expect(DeepLinkService.propertyDeepLinkPath('abc-slug'), '/property/abc-slug');
      expect(DeepLinkService.propertyDeepLinkPath('uuid-1234-5678'), '/property/uuid-1234-5678');
    });

    test('handles empty property id', () {
      expect(DeepLinkService.propertyDeepLinkPath(''), '/property/');
    });

    test('handles large numeric property ids', () {
      expect(
        DeepLinkService.propertyDeepLinkPath('999999999'),
        '/property/999999999',
      );
    });

    test('produces a path starting with /property/', () {
      final path = DeepLinkService.propertyDeepLinkPath('xyz');
      expect(path, startsWith('/property/'));
    });

    test('replaces only the :id placeholder', () {
      final path = DeepLinkService.propertyDeepLinkPath('77');
      expect(path, isNot(contains(':id')));
      expect(path, '/property/77');
    });
  });

  group('DeepLinkService.handleDeepLinkForTest', () {
    late DeepLinkService service;
    late MockAuthRepository authRepository;

    setUp(() {
      Get.testMode = true;
      authRepository = MockAuthRepository();
      service = DeepLinkService();
      Get.addPages([
        GetPage(
          name: AppRoutes.propertyDeepLink,
          page: () => const SizedBox.shrink(),
        ),
      ]);
    });

    tearDown(Get.reset);

    test('parses /property/:id path and schedules navigation', () async {
      expect(
        () => service.handleDeepLinkForTest(
          Uri.parse('https://the360ghar.com/property/42'),
        ),
        returnsNormally,
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });

    test('parses short /p/:id path without throwing', () async {
      expect(
        () => service.handleDeepLinkForTest(Uri.parse('https://the360ghar.com/p/99')),
        returnsNormally,
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });

    test('logs unparseable paths without throwing', () {
      expect(
        () => service.handleDeepLinkForTest(Uri.parse('https://the360ghar.com/about')),
        returnsNormally,
      );
      expect(
        () => service.handleDeepLinkForTest(Uri.parse('https://the360ghar.com/property/')),
        returnsNormally,
      );
    });

    test('routes OAuth redirect through AuthRepository when registered', () async {
      Get.put<AuthRepository>(authRepository);
      final uri = Uri.parse('https://the360ghar.com/auth/callback?code=abc');
      when(() => authRepository.isOAuthRedirectUri(uri)).thenReturn(true);
      when(() => authRepository.completeOAuthFromUri(uri)).thenAnswer((_) async {});

      service.handleDeepLinkForTest(uri);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(() => authRepository.isOAuthRedirectUri(uri)).called(1);
      verify(() => authRepository.completeOAuthFromUri(uri)).called(1);
    });

    test('handles OAuth completion failure without throwing', () async {
      Get.put<AuthRepository>(authRepository);
      final uri = Uri.parse('https://the360ghar.com/auth/callback?code=fail');
      when(() => authRepository.isOAuthRedirectUri(uri)).thenReturn(true);
      when(() => authRepository.completeOAuthFromUri(uri))
          .thenThrow(Exception('oauth failed'));

      expect(() => service.handleDeepLinkForTest(uri), returnsNormally);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('ignores auth repository when URI is not an OAuth redirect', () {
      Get.put<AuthRepository>(authRepository);
      final uri = Uri.parse('https://the360ghar.com/property/7');
      when(() => authRepository.isOAuthRedirectUri(uri)).thenReturn(false);

      expect(() => service.handleDeepLinkForTest(uri), returnsNormally);
      verify(() => authRepository.isOAuthRedirectUri(uri)).called(1);
      verifyNever(() => authRepository.completeOAuthFromUri(any()));
    });
  });
}
