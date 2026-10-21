import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/presentation/controllers/phone_entry_controller.dart';
import 'package:ghar360/features/auth/presentation/views/phone_entry_view.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_form_fields.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_form_harness.dart';

void main() {
  late AuthFormHarness h;
  setUp(() {
    h = AuthFormHarness();
  });
  tearDown(() {
    h.close();
  });

  testWidgets('entry renders identifier, Google, and continue controls', (tester) async {
    try {
      await h.pump(tester, const PhoneEntryView());
      expect(find.byKey(const ValueKey('qa.auth.phone_entry.identifier_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.auth.phone_entry.continue')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.auth.google_signin')), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  for (final value in ['', 'invalid', '  ']) {
    testWidgets('invalid identifier "$value" blocks repository request', (tester) async {
      try {
        await h.pump(tester, const PhoneEntryView());
        await tester.enterText(find.byType(TextFormField), value);
        await tester.ensureVisible(find.byKey(const ValueKey('qa.auth.phone_entry.continue')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('qa.auth.phone_entry.continue')));
        await tester.pump();
        verifyNever(() => h.repository.checkIdentifierStatus(any()));
      } finally {
        await tester.pumpWidget(const SizedBox());
        h.close();
      }
    });
  }
  testWidgets('valid identifier calls status check and changes route', (tester) async {
    try {
      await h.pump(tester, const PhoneEntryView());
      await tester.enterText(find.byType(TextFormField), 'test@example.com');
      await tester.ensureVisible(find.byKey(const ValueKey('qa.auth.phone_entry.continue')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('qa.auth.phone_entry.continue')));
      await tester.pumpAndSettle();
      verify(() => h.repository.checkIdentifierStatus('test@example.com')).called(1);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('pending entry request keeps button dimensions and disables duplicate tap', (
    tester,
  ) async {
    try {
      final pending = Completer<void>();
      when(() => h.repository.signInWithGoogle()).thenAnswer((_) => pending.future);
      await h.pump(tester, const PhoneEntryView());
      final button = find.byKey(const ValueKey('qa.auth.phone_entry.continue'));
      final size = tester.getSize(button);
      final request = h.container.read(phoneEntryProvider.notifier).signInWithGoogle();
      await tester.pump();
      expect(tester.getSize(button), size);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      pending.complete();
      await request;
      await tester.pump();
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('typed error is inline and can be cleared without losing text', (tester) async {
    try {
      await h.pump(tester, const PhoneEntryView());
      await tester.enterText(find.byType(TextFormField), 'test@example.com');
      h.container.read(phoneEntryProvider.notifier).invalid('identifier_invalid');
      await tester.pump();
      expect(find.byType(AuthFormError), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'new@example.com');
      expect(h.container.read(phoneEntryProvider).error, isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('last method appears with masked hint', (tester) async {
    try {
      await h.repository.lastAuthMethodStore.save(
        AuthMethod.emailPassword,
        identifier: 'john@example.com',
      );
      await h.pump(tester, const PhoneEntryView());
      expect(find.textContaining('j***@example.com'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('no last method leaves hint hidden', (tester) async {
    try {
      await h.pump(tester, const PhoneEntryView());
      expect(find.textContaining('Last used'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  for (final brightness in Brightness.values) {
    testWidgets('entry fits narrow ${brightness.name} screen with large text', (tester) async {
      try {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await h.pump(tester, const PhoneEntryView(), scale: 2, brightness: brightness);
        await tester.pump();
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        h.close();
      }
    });
  }
}
