import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:sms_autofill/sms_autofill.dart';

/// Reusable 6-digit OTP input with Android SMS autofill (`CodeAutoFill`) and
/// `autofillHints: oneTimeCode` for the iOS keyboard suggestion bar.
///
/// Mirrors the `360-flatmates` `otp_page.dart` reference: it listens for the
/// incoming SMS code on Android and fills the field + auto-submits on a full
/// code. The parent owns the [controller]; [onCompleted] fires when 6 digits
/// are present (via typing, paste, or SMS autofill).
class OtpInputField extends StatefulWidget {
  const OtpInputField({
    required this.controller,
    this.onCompleted,
    this.onChanged,
    this.autofocus = true,
    this.semanticsLabel,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final String? semanticsLabel;

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> with CodeAutoFill {
  bool _smsListening = false;

  bool get _smsAutofillSupported => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    if (_smsAutofillSupported) {
      _startListeningForSms();
    }
  }

  Future<void> _startListeningForSms() async {
    try {
      await SmsAutoFill().listenForCode();
      _smsListening = true;
    } catch (e) {
      // SMS autofill unavailable (e.g. emulator without Play services).
      DebugLogger.debug('OtpInputField: SMS autofill unavailable: $e');
    }
  }

  @override
  void codeUpdated() {
    final value = code;
    if (value != null && value.length == 6) {
      widget.controller.text = value;
      widget.onChanged?.call(value);
      widget.onCompleted?.call(value);
    }
  }

  @override
  void dispose() {
    if (_smsListening) {
      try {
        SmsAutoFill().unregisterListener();
      } catch (e) {
        DebugLogger.debug('🟡 SMS listener unregister failed (ignored): $e');
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.semanticsLabel ?? 'qa.auth.otp_input';
    return Semantics(
      label: label,
      identifier: label,
      child: TextFormField(
        key: ValueKey(label),
        controller: widget.controller,
        autofocus: widget.autofocus,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        maxLength: 6,
        textAlign: TextAlign.center,
        autofillHints: const [AutofillHints.oneTimeCode],
        style: const TextStyle(
          color: AppDesign.overlayLight,
          letterSpacing: 8,
          fontWeight: FontWeight.w700,
          fontSize: 24,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        decoration: InputDecoration(
          labelText: 'enter_otp'.tr,
          hintText: 'otp_hint'.tr,
          counterText: '',
          prefixIcon: const Icon(Icons.security),
        ),
        onChanged: (value) {
          widget.onChanged?.call(value);
          if (value.length == 6) {
            widget.onCompleted?.call(value);
          }
        },
      ),
    );
  }
}
