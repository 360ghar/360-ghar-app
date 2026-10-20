// lib/features/auth/data/models/identifier_status.dart

import 'package:ghar360/core/data/models/wire_enums.dart';

export 'package:ghar360/core/data/models/wire_enums.dart'
    show IdentifierChannel, IdentifierNextStep;

/// Response of `POST /api/v1/auth/identifier-status` (`IdentifierStatusResponse`).
///
/// Backend contract:
///   req  {identifier: string}
///   res  {exists, verified, has_password, channel: "email"|"phone",
///         next_step: "password"|"otp"}
/// where next_step == "password" iff exists && verified && has_password,
/// else "otp".
///
/// A channel or next step this app does not know is a contract break: the sign-in flow cannot
/// pick a path for it, so parsing throws a [FormatException] instead of choosing one.
class IdentifierStatus {
  final bool exists;
  final bool verified;
  final bool hasPassword;
  final IdentifierChannel channel;
  final IdentifierNextStep nextStep;

  const IdentifierStatus({
    required this.exists,
    required this.verified,
    required this.hasPassword,
    required this.channel,
    required this.nextStep,
  });

  bool get isPasswordStep => nextStep == IdentifierNextStep.password;
  bool get isOtpStep => nextStep == IdentifierNextStep.otp;
  bool get isEmail => channel == IdentifierChannel.email;
  bool get isPhone => channel == IdentifierChannel.phone;

  /// New user: no account exists yet → signup (OTP + set password).
  bool get isNewUser => !exists;

  factory IdentifierStatus.fromJson(Map<String, dynamic> json) {
    final exists = json['exists'];
    final verified = json['verified'];
    final hasPassword = json['has_password'];
    if (exists is! bool || verified is! bool || hasPassword is! bool) {
      throw const FormatException('identifier-status: exists, verified and has_password are bools');
    }
    final channel = IdentifierChannel.fromJson(json['channel']);
    final nextStep = IdentifierNextStep.fromJson(json['next_step']);
    if (channel == null || nextStep == null) {
      throw const FormatException('identifier-status: unknown channel or next_step');
    }
    return IdentifierStatus(
      exists: exists,
      verified: verified,
      hasPassword: hasPassword,
      channel: channel,
      nextStep: nextStep,
    );
  }

  @override
  String toString() =>
      'IdentifierStatus(exists: $exists, verified: $verified, '
      'hasPassword: $hasPassword, channel: ${channel.name}, '
      'nextStep: ${nextStep.name})';
}
