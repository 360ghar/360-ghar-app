import 'package:ghar360/features/auth/data/models/identifier_status.dart';

/// Route data contains the selected identifier; never a password or OTP.
class AuthFlowArgs {
  const AuthFlowArgs({required this.identifier, required this.status});
  final String identifier;
  final IdentifierStatus status;
}
