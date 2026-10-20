import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/auth/presentation/controllers/phone_entry_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, AuthResponse;

import '../../../../helpers/auth_form_harness.dart';

void main() {
  late AuthFormHarness h;
  setUp(() {
    h = AuthFormHarness();
  });
  tearDown(() {
    h.close();
  });

  test('entry defaults are idle with no error', () {
    expect(h.container.read(phoneEntryProvider).loading, false);
    expect(h.container.read(phoneEntryProvider).error, isNull);
  });
  test('identifier check normalizes email and returns typed routing data', () async {
    h.listen(phoneEntryProvider);
    final result = await h.container
        .read(phoneEntryProvider.notifier)
        .checkIdentifier(' Test@Example.COM ');
    expect(result?.identifier, 'test@example.com');
    expect(result?.status.isPasswordStep, true);
  });
  test('identifier check normalizes phone', () async {
    h.listen(phoneEntryProvider);
    final result = await h.container
        .read(phoneEntryProvider.notifier)
        .checkIdentifier('9876543210');
    expect(result?.identifier, '+919876543210');
  });
  test('failed identifier check keeps input available for retry', () async {
    h.listen(phoneEntryProvider);
    when(() => h.repository.checkIdentifierStatus(any())).thenThrow(NetworkException('offline'));
    expect(
      await h.container.read(phoneEntryProvider.notifier).checkIdentifier('test@example.com'),
      isNull,
    );
    expect(h.container.read(phoneEntryProvider).error, isA<NetworkException>());
  });
  for (final apple in [false, true]) {
    test('${apple ? 'Apple' : 'Google'} starts loading and prevents duplicates', () async {
      h.listen(phoneEntryProvider);
      final pending = Completer<AuthResponse>();
      if (apple) {
        when(() => h.repository.signInWithApple()).thenAnswer((_) => pending.future);
      } else {
        when(() => h.repository.signInWithGoogle()).thenAnswer((_) => pending.future);
      }
      final c = h.container.read(phoneEntryProvider.notifier);
      final first = apple ? c.signInWithApple() : c.signInWithGoogle();
      expect(h.container.read(phoneEntryProvider).loading, true);
      expect(await (apple ? c.signInWithApple() : c.signInWithGoogle()), false);
      pending.complete(AuthResponse());
      expect(await first, true);
      expect(h.container.read(phoneEntryProvider).loading, false);
    });
    test('${apple ? 'Apple' : 'Google'} cancellation remains silent', () async {
      h.listen(phoneEntryProvider);
      if (apple) {
        when(() => h.repository.signInWithApple()).thenThrow(const AuthException('cancelled'));
      } else {
        when(() => h.repository.signInWithGoogle()).thenThrow(const AuthException('cancelled'));
      }
      final c = h.container.read(phoneEntryProvider.notifier);
      await (apple ? c.signInWithApple() : c.signInWithGoogle());
      expect(h.container.read(phoneEntryProvider).error, isNull);
    });
    for (final error in [const AuthException('raw private server detail'), Exception('secret')]) {
      test('${apple ? 'Apple' : 'Google'} ${error.runtimeType} becomes sanitized error', () async {
        h.listen(phoneEntryProvider);
        if (apple) {
          when(() => h.repository.signInWithApple()).thenThrow(error);
        } else {
          when(() => h.repository.signInWithGoogle()).thenThrow(error);
        }
        final c = h.container.read(phoneEntryProvider.notifier);
        await (apple ? c.signInWithApple() : c.signInWithGoogle());
        final failure = h.container.read(phoneEntryProvider).error;
        expect(failure, isA<AppException>());
        expect(failure!.message, isNot(contains('secret')));
        expect(failure.message, isNot(contains('private')));
      });
    }
  }
  test('late entry request completion after scope disposal is ignored', () async {
    final pending = Completer<void>();
    when(() => h.repository.signInWithGoogle()).thenAnswer((_) => pending.future);
    final sub = h.listen(phoneEntryProvider);
    final request = h.container.read(phoneEntryProvider.notifier).signInWithGoogle();
    sub.close();
    await h.container.pump();
    pending.complete();
    expect(await request, false);
  });
}
