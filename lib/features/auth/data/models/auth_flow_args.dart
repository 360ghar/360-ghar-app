import 'package:ghar360/features/auth/data/models/identifier_status.dart';

/// Route data contains the selected identifier; never a password or OTP.
class AuthFlowArgs {
  const AuthFlowArgs({required this.identifier, required this.status});
  final String identifier;
  final IdentifierStatus status;

  // Value equality: this is a provider family key, and a new instance must not rebuild the
  // controller (which can re-send an OTP).
  @override
  bool operator ==(Object other) =>
      other is AuthFlowArgs && other.identifier == identifier && other.status == status;

  @override
  int get hashCode => Object.hash(identifier, status);
}
