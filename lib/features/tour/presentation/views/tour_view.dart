import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/tour_url.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/max_content_width.dart';
import 'package:ghar360/core/widgets/common/tour_webview.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/paper_vignette.dart';
import 'package:ghar360/core/widgets/paper/scene_header_sliver.dart';

/// The native WebView and its timers belong to the mounted media widget.
class TourView extends StatelessWidget {
  const TourView({super.key, required this.url, this.title});
  final String url;
  final String? title;
  void _back(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(AppRoutes.discover);
    }
  }

  @override
  Widget build(BuildContext context) {
    final validated = TourUrl.validate(url);
    final label = title ?? context.l10n.text('virtual_tour_title');
    final dark = Theme.of(context).brightness == Brightness.dark;
    final design = context.design;
    // The far skyline over the sheet; the tour fills the sheet under its cut
    // lip. Nothing scrolls, so every drag goes to the tour.
    return Scaffold(
      key: const ValueKey('qa.tour.screen'),
      backgroundColor: design.background,
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SceneHeaderSliver(
            title: label,
            scene: PaperSceneSpec.skyline(),
            seed: 'tour',
            leading: IconButton(
              tooltip: context.l10n.text('back'),
              onPressed: () => _back(context),
              icon: const PaperIcon(KnifeIcon.arrowLeft, size: 22),
            ),
            actions: [
              if (validated != null)
                Builder(
                  builder: (buttonContext) => IconButton(
                    tooltip: context.l10n.text('share'),
                    icon: const PaperIcon(KnifeIcon.share, size: 22),
                    onPressed: () async {
                      final box = buttonContext.findRenderObject() as RenderBox?;
                      final origin = box != null && box.hasSize
                          ? box.localToGlobal(Offset.zero) & box.size
                          : null;
                      try {
                        await SharePlus.instance.share(
                          ShareParams(text: validated, subject: label, sharePositionOrigin: origin),
                        );
                      } catch (_) {
                        if (context.mounted) {
                          AppToast.error(
                            context.l10n.text('error'),
                            context.l10n.text('unable_to_open_link'),
                          );
                        }
                      }
                    },
                  ),
                ),
            ],
          ),
          SliverFillRemaining(
            child: ColoredBox(
              color: design.surface,
              child: validated == null
                  ? Semantics(
                      identifier: 'qa.tour.invalid_state',
                      child: StateBlock(
                        scene: PaperScene.notFound,
                        seed: 'route',
                        title: context.l10n.text('tour_unavailable_title'),
                        message: context.l10n.text('unable_to_open_link'),
                        actionLabel: context.l10n.text('back'),
                        onAction: () => _back(context),
                        identifier: 'qa.tour.invalid_state',
                      ),
                    )
                  : SafeArea(
                      top: false,
                      child: MaxContentWidth(
                        child: Semantics(
                          identifier: 'qa.tour.webview',
                          label: label,
                          child: TourWebView(
                            key: ValueKey(validated),
                            tourUrl: validated,
                            backgroundColor: design.surface,
                            bodyBackgroundCss: dark ? '#000' : '#fff',
                            applyPageChromeStyles: true,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
