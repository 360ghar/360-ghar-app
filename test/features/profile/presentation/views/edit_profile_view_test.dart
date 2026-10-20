import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/profile/presentation/controllers/edit_profile_controller.dart';
import 'package:ghar360/features/profile/presentation/views/edit_profile_view.dart';
import '../../../../helpers/knife_finders.dart';
import '../../../../helpers/profile_test_harness.dart';

void main() {
  late ProfileHarness h;
  setUp(() => h = ProfileHarness());
  tearDown(() => h.close());
  Finder key(String value) => find.byKey(ValueKey('qa.profile.edit.$value'));
  Future<void> pump(WidgetTester tester) => h.pump(tester, const EditProfileView());
  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(key('save'));
    await tester.pumpAndSettle();
    await tester.tap(key('save'));
    await tester.pump();
  }

  testWidgets('loads user fields, avatar initial and birth date', (tester) async {
    h.session.initial = h.session.initial.copyWith(
      user: profile().copyWith(
        fullName: 'Alice',
        email: 'alice@example.com',
        dateOfBirth: '1995-06-15',
        preferences: const UserPreferences(locationPreference: ['Mumbai']),
      ),
    );
    await pump(tester);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('alice@example.com'), findsOneWidget);
    expect(find.text('Mumbai'), findsOneWidget);
    expect(find.text('15/06/1995'), findsOneWidget);
    expect(tester.widget<TextFormField>(key('email_input')).enabled, isFalse);
    expect(tester.widget<TextFormField>(key('full_name_input')).enabled, isTrue);
  });
  testWidgets('no saved place displays empty', (tester) async {
    h.session.initial = h.session.initial.copyWith(
      user: profile().copyWith(preferences: const UserPreferences()),
    );
    await pump(tester);
    expect(tester.widget<TextFormField>(key('location_input')).controller!.text, isEmpty);
  });
  testWidgets('null user has empty local form and fallback avatar', (tester) async {
    h.session.initial = h.session.initial.copyWith(user: null);
    await pump(tester);
    expect(find.text('U'), findsOneWidget);
    expect(find.text(tr('select_your_date_of_birth')), findsOneWidget);
  });
  testWidgets('invalid date has placeholder and can open date picker', (tester) async {
    h.session.initial = h.session.initial.copyWith(
      user: profile().copyWith(dateOfBirth: 'not-a-date'),
    );
    await pump(tester);
    expect(find.text(tr('select_your_date_of_birth')), findsOneWidget);
    await tester.ensureVisible(key('dob_input'));
    await tester.pump();
    await tester.tap(key('dob_input'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });
  testWidgets('clear birth date is persisted as null', (tester) async {
    await pump(tester);
    await tester.ensureVisible(findKnife(KnifeIcon.close));
    await tester.pump();
    await tester.tap(findKnife(KnifeIcon.close));
    await tester.pump();
    expect(find.text(tr('select_your_date_of_birth')), findsOneWidget);
    await save(tester);
    await tester.pumpAndSettle();
    expect(h.session.lastProfile!['date_of_birth'], isNull);
    expect(find.text('Back destination'), findsOneWidget);
  });
  testWidgets('empty name validates without submitting', (tester) async {
    await pump(tester);
    await tester.enterText(key('full_name_input'), '');
    await save(tester);
    expect(h.session.lastProfile, isNull);
    expect(find.text(tr('name_required')), findsOneWidget);
  });
  testWidgets('failed save retains local draft and route, retry succeeds', (tester) async {
    h.session.save = () async => throw NetworkException('offline');
    await pump(tester);
    await tester.enterText(key('full_name_input'), 'Draft Name');
    await save(tester);
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileView), findsOneWidget);
    expect(find.text('Draft Name'), findsOneWidget);
    expect(h.container.read(editProfileProvider).error, isA<NetworkException>());
    h.session.save = null;
    await save(tester);
    await tester.pumpAndSettle();
    expect(find.text('Back destination'), findsOneWidget);
    expect(h.session.lastProfile!['full_name'], 'Draft Name');
  });
  testWidgets('avatar upload keeps the form mounted and drafts intact', (tester) async {
    final pending = Completer<bool>();
    h.session.upload = () => pending.future;
    await pump(tester);
    await tester.enterText(key('full_name_input'), 'Draft');
    final future = h.container.read(editProfileProvider.notifier).uploadImage('/photo.jpg');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(key('save'), findsOneWidget);
    pending.complete(true);
    await future;
    await tester.pump();
    expect(find.text('Draft'), findsOneWidget);
  });
  testWidgets('image source sheet offers camera and gallery then cancels', (tester) async {
    await pump(tester);
    await tester.tap(key('pick_image'));
    await tester.pumpAndSettle();
    expect(find.text(tr('take_photo')), findsOneWidget);
    expect(find.text(tr('choose_from_gallery')), findsOneWidget);
    Navigator.of(tester.element(find.text(tr('take_photo')))).pop();
    await tester.pumpAndSettle();
    expect(h.session.lastImage, isNull);
  });
  testWidgets('invalid avatar URL uses user initial', (tester) async {
    h.session.initial = h.session.initial.copyWith(
      user: profile().copyWith(fullName: 'Bob', profileImageUrl: 'invalid-url'),
    );
    await pump(tester);
    expect(find.text('B'), findsOneWidget);
  });
  testWidgets('server field errors show under their fields and keep the draft', (tester) async {
    h.session.save = () async => throw ValidationException(
      'The request was not valid.',
      code: 'VALIDATION_ERROR',
      fieldErrors: {
        'full_name': ['string_too_long'],
        'date_of_birth': ['date_from_datetime_parsing'],
        'preferences.location': ['string_type'],
      },
    );
    await pump(tester);
    await tester.enterText(key('full_name_input'), 'A very long draft name');
    await tester.enterText(key('location_input'), 'Draft city');
    await save(tester);
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileView), findsOneWidget);
    expect(find.text('A very long draft name'), findsOneWidget);
    expect(find.text('Draft city'), findsOneWidget);
    expect(find.text(tr('field_error_too_long')), findsOneWidget);
    expect(find.text(tr('field_error_invalid')), findsNWidgets(2));
    expect(find.text(tr('form_check_fields')), findsOneWidget);
    expect(find.text('VALIDATION_ERROR'), findsNothing);

    await tester.enterText(key('full_name_input'), 'Shorter');
    await tester.pump();
    expect(find.text(tr('field_error_too_long')), findsNothing);
    expect(find.text(tr('field_error_invalid')), findsNWidgets(2));
  });
}
