import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/features/auth/data/models/auth_flow_args.dart';
import 'package:ghar360/features/auth/data/models/identifier_status.dart';

void main() {
  IdentifierStatus status() => const IdentifierStatus(
    exists: true,
    verified: true,
    hasPassword: false,
    channel: IdentifierChannel.phone,
    nextStep: IdentifierNextStep.otp,
  );

  test('equal args are one provider family key', () {
    final a = AuthFlowArgs(identifier: '9876543210', status: status());
    final b = AuthFlowArgs(identifier: '9876543210', status: status());
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(AuthFlowArgs(identifier: '9876543211', status: status())));
  });
}
