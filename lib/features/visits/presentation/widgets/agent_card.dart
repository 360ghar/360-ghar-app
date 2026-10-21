import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ghar360/core/data/models/agent_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/robust_network_image.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';

/// The relationship manager as a visiting card laid on the sheet: mint stock
/// with a hand-cut edge, a short shadow and a slight turn. The name is in
/// the display face; role, rating and level are text; call and WhatsApp
/// are bare icons.
class AgentCard extends StatelessWidget {
  const AgentCard({super.key, required this.agent, this.onCall, this.onWhatsApp});
  final AgentModel agent;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;

  /// The card's turn on the sheet: under one degree.
  static const turn = -0.6 * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final palette = context.design;
    final text = Theme.of(context).textTheme;
    final placeholder = SizedBox.square(
      dimension: 48,
      child: Center(child: PaperIcon(KnifeIcon.user, color: palette.textSecondary)),
    );
    final rating = agent.userSatisfactionRating;
    final contact = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onCall,
          tooltip: context.l10n.text('call'),
          icon: PaperIcon(KnifeIcon.phone, color: palette.accent),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
        IconButton(
          onPressed: onWhatsApp,
          tooltip: context.l10n.text('whatsapp'),
          icon: PaperIcon(KnifeIcon.chat, color: palette.accent),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
      ],
    );
    // Large text gives the words the full width; the icons move under them.
    final beside = MediaQuery.textScalerOf(context).scale(14) <= 21;
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(agent.name, style: text.headlineSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(
          context.l10n.text('relationship_manager_card'),
          style: text.bodySmall?.copyWith(color: palette.textSecondary),
        ),
        Text.rich(
          TextSpan(
            children: [
              // No ratings yet reads as nothing, not as "0.0".
              if (rating > 0) ...[
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: PaperIcon(KnifeIcon.star, size: 16, color: palette.accent),
                ),
                TextSpan(
                  text:
                      ' ${rating.toStringAsFixed(1)}${agent.experienceLevelString == null ? '' : ' · '}',
                ),
              ],
              if (agent.experienceLevelString case final level?)
                TextSpan(text: context.l10n.text(level)),
            ],
          ),
          style: text.bodySmall?.copyWith(color: palette.textSecondary),
        ),
        if (!beside) ...[const SizedBox(height: 4), contact],
      ],
    );
    return Padding(
      // Room for the turned corners and the shadow.
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      child: Transform.rotate(
        angle: turn,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: palette.slip,
            shape: CutBorder(
              seed: 'agent-${agent.id}',
              amp: 1.5,
              shadows: paperShadows(PaperElevation.low, palette.shadowOn(palette.surface)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
            child: Row(
              crossAxisAlignment: beside ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                RobustNetworkImageExtension.avatar(
                  imageUrl: agent.avatarUrl ?? '',
                  size: 48,
                  placeholder: placeholder,
                  errorWidget: placeholder,
                ),
                const SizedBox(width: 14),
                Expanded(child: words),
                if (beside) contact,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
