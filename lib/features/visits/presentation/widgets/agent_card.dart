import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/data/models/agent_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/widgets/common/robust_network_image.dart';

class AgentCard extends StatelessWidget {
  final AgentModel agent;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;

  const AgentCard({super.key, required this.agent, this.onCall, this.onWhatsApp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppDesign.editorialWarm.withValues(alpha: 0.08),
            AppDesign.editorialWarm.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppDesign.editorialWarm.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Gold ring avatar
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppDesign.primaryYellow, width: 2),
            ),
            child: RobustNetworkImageExtension.avatar(
              imageUrl: agent.avatarUrl ?? '',
              size: 44,
              placeholder: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: Icon(Icons.person, size: 22, color: AppDesign.iconColor),
              ),
              errorWidget: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: Icon(Icons.person, size: 22, color: AppDesign.iconColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your Relationship Manager'.tr,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppDesign.primaryYellowDark,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  agent.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppDesign.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: AppDesign.primaryYellow),
                    const SizedBox(width: 3),
                    Text(
                      agent.userSatisfactionRating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppDesign.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.work_outline, size: 14, color: AppDesign.iconColor),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        agent.experienceLevelString,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppDesign.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _CompactIconButton(
            icon: Icons.phone,
            tooltip: 'call'.tr,
            foreground: AppDesign.primaryYellow,
            background: AppDesign.primaryYellow.withValues(alpha: 0.08),
            borderColor: AppDesign.primaryYellow.withValues(alpha: 0.4),
            onTap: onCall ?? () {},
          ),
          const SizedBox(width: 8),
          _CompactIconButton(
            icon: Icons.message,
            tooltip: 'whatsapp'.tr,
            foreground: AppDesign.buttonText,
            background: AppDesign.accentGreen,
            borderColor: AppDesign.accentGreen,
            onTap: onWhatsApp ?? () {},
          ),
        ],
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color foreground;
  final Color background;
  final Color borderColor;
  final VoidCallback onTap;

  const _CompactIconButton({
    required this.icon,
    required this.tooltip,
    required this.foreground,
    required this.background,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: foreground),
        ),
      ),
    );
  }
}
