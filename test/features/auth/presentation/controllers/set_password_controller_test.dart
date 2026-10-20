import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/presentation/controllers/set_password_controller.dart';
import '../../../../helpers/auth_form_harness.dart';

void main() {
  late AuthFormHarness h;
  setUp(() {
    h = AuthFormHarness();
  });
  tearDown(() {
    h.close();
  });

  test('set-password starts idle', () {
    expect(h.container.read(setPasswordProvider).loading, false);
    expect(h.container.read(setPasswordProvider).error, isNull);
  });
  test('successful password write records email method', () async {
    h.listen(setPasswordProvider);
    expect(await h.container.read(setPasswordProvider.notifier).submit('Password123'), true);
    expect(h.session.passwordWrites, 1);
    verify(
      () => h.repository.recordLastMethod(
        AuthMethod.emailPassword,
        identifier: any(named: 'identifier'),
      ),
    ).called(1);
  });
  test('failed password write remains retryable and records no success', () async {
    h.listen(setPasswordProvider);
    h.session.passwordSuccess = false;
    expect(await h.container.read(setPasswordProvider.notifier).submit('Password123'), false);
    expect(h.container.read(setPasswordProvider).error, isA<AppException>());
    verifyNever(() => h.repository.recordLastMethod(any(), identifier: any(named: 'identifier')));
  });
}
