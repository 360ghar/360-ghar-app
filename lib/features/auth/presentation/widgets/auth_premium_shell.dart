import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/responsive.dart';
import 'package:ghar360/core/widgets/common/symmetric_safe_area.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/paper_skyline.dart';
import 'package:ghar360/core/widgets/paper/sheet_sliver.dart';

/// The frame of every sign-in screen: a strip of the Gurugram skyline at the
/// top, then a hand-cut paper sheet with the title and a flat form.
class AuthPremiumShell extends StatelessWidget {
  const AuthPremiumShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final text = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    // The skyline gives way to the form while the keyboard is up.
    final keyboard = media.viewInsets.bottom > 0;
    // The wordmark row sits on plain sky under the status bar; the city
    // starts below it, so the kite and the sun never run into the name.
    const titleRow = 56.0;
    final band = keyboard ? 72.0 : math.min(176.0, media.size.height * 0.22);
    final header = media.padding.top + titleRow + band;
    // A centered (wide) form takes the same inset on both sides; a phone's
    // full-width form only clears the side that has the cut-out.
    final wide = media.size.width >= kCompactBreakpoint;
    final side = symmetricSideInset(context);
    return Scaffold(
      backgroundColor: design.surface,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        excludeFromSemantics: true,
        onTap: () => FocusScope.of(context).unfocus(),
        child: LayoutBuilder(
          builder: (context, box) => CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: header,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: PaperSkylineStrip(artTop: media.padding.top + titleRow),
                      ),
                      // The sheet's hand-cut lip belongs to this sliver: a
                      // scroll view paints earlier slivers over later ones, so a
                      // lip drawn by the form sliver would sit under the city.
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: kPaperLip,
                        child: PaperLip(seed: 'auth'),
                      ),
                      Positioned(
                        top: media.padding.top + 4,
                        left: 4 + media.padding.left,
                        right: 4 + media.padding.right,
                        child: Row(
                          children: [
                            if (onBack != null)
                              IconButton(
                                tooltip: context.l10n.text('back'),
                                onPressed: onBack,
                                icon: const PaperIcon(KnifeIcon.arrowLeft, size: 22),
                              )
                            else
                              const SizedBox.square(dimension: 48),
                            Expanded(
                              child: Text(
                                context.l10n.text('app_name'),
                                textAlign: TextAlign.center,
                                style: text.headlineSmall,
                              ),
                            ),
                            const SizedBox.square(dimension: 48),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // The scaffold is the sheet colour, so the sheet needs no fill below.
              // A tall wide window (an iPad) centres the form under the city;
              // a phone keeps it at the top. Either scrolls when it must.
              SliverToBoxAdapter(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: math.max(0, box.maxHeight - header)),
                  child: Align(
                    alignment: wide ? Alignment.center : Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          20 + (wide ? side : media.padding.left),
                          16,
                          20 + (wide ? side : media.padding.right),
                          media.padding.bottom + 24,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              identifier: 'qa.auth.shell.title',
                              header: true,
                              child: Text(title, style: text.headlineLarge),
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                subtitle,
                                style: text.bodyMedium?.copyWith(color: design.textSecondary),
                              ),
                            ],
                            const SizedBox(height: 24),
                            child,
                            if (footer case final footer?) ...[
                              const SizedBox(height: 16),
                              DefaultTextStyle.merge(
                                style: text.bodySmall?.copyWith(color: design.textSecondary),
                                textAlign: TextAlign.center,
                                child: Center(child: footer),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A form-level error under the fields: an icon and one line, announced.
class AuthInlineError extends StatelessWidget {
  const AuthInlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.trim().isEmpty) return const SizedBox.shrink();
    final error = context.design.error;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: PaperIcon(KnifeIcon.alert, size: 18, color: error),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: error, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
