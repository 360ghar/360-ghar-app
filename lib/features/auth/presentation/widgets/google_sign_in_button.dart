import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';

/// "Continue with Google" with the official four-colour G mark, on a plain
/// sheet as Google's sign-in branding asks.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({required this.onPressed, this.isLoading = false, super.key});

  final VoidCallback? onPressed;
  final bool isLoading;

  // The standard Google "G" from the Sign in with Google branding guidelines.
  static const _mark =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
      '<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>'
      '<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>'
      '<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>'
      '<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>'
      '</svg>';

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    // A floor, not a fixed height: at large text a fixed box shaved the
    // Devanagari vowel signs above and below the label.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Semantics(
        identifier: 'qa.auth.google_signin',
        child: OutlinedButton(
          key: const ValueKey('qa.auth.google_signin'),
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: design.raised,
            foregroundColor: design.textPrimary,
            side: BorderSide(color: design.fieldBorder),
          ),
          child: isLoading
              ? LoadingStates.buttonSpinner(size: 20, color: design.textPrimary)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.string(_mark, width: 20, height: 20),
                    const SizedBox(width: 12),
                    Flexible(child: Text(context.l10n.text('continue_with_google'))),
                  ],
                ),
        ),
      ),
    );
  }
}
