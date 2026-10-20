import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
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
      if (!mounted) {
        await SmsAutoFill().unregisterListener();
        return;
      }
      _smsListening = true;
    } catch (e) {
      // SMS autofill unavailable (e.g. emulator without Play services).
      DebugLogger.debug('SMS autofill unavailable', e.runtimeType);
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
        DebugLogger.debug('SMS listener removal failed', e.runtimeType);
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.semanticsLabel ?? 'qa.auth.otp_input';
    return Semantics(
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
        style: TextStyle(
          color: context.design.textPrimary,
          letterSpacing: 8,
          fontWeight: FontWeight.w700,
          fontSize: 24,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        decoration: InputDecoration(
          labelText: context.l10n.text('enter_otp'),
          hintText: context.l10n.text('otp_hint'),
          counterText: '',
          prefixIcon: const Padding(
            padding: EdgeInsets.all(12),
            child: PaperIcon(KnifeIcon.shield, size: 20),
          ),
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
