import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/widgets/common/robust_network_image.dart';

class VisitCard extends StatelessWidget {
  final VisitModel visit;
  final bool isUpcoming;
  final VoidCallback onReschedule;
  final VoidCallback onCancel;
  final VoidCallback? onTap;

  const VisitCard({
    super.key,
    required this.visit,
    required this.isUpcoming,
    required this.onReschedule,
    required this.onCancel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dt = visit.scheduledDate;
    final dateText =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final hour = dt.hour;
    final minute = dt.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeText = '$displayHour:${minute.toString().padLeft(2, '0')} $period';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppDesign.getCardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RobustNetworkImage(
                  imageUrl: visit.property?.mainImage ?? visit.property?.mainImageUrl ?? '',
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(10),
                  errorWidget: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppDesign.inputBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.home_work_rounded, size: 28, color: AppDesign.iconColor),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              visit.property?.title ?? visit.propertyTitle,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppDesign.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusChip(visit.status),
                        ],
                      ),
                      if (visit.property != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          visit.property!.addressDisplay,
                          style: TextStyle(fontSize: 12, color: AppDesign.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (visit.property!.bedrooms != null) '${visit.property!.bedrooms}BHK',
                            if (visit.property!.bathrooms != null) '${visit.property!.bathrooms}B',
                            if (visit.property!.areaSqft != null)
                              '${visit.property!.areaSqft!.toStringAsFixed(0)} sqft',
                          ].join(' · '),
                          style: TextStyle(fontSize: 11, color: AppDesign.textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 2,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 13,
                                color: AppDesign.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateText,
                                style: TextStyle(fontSize: 11, color: AppDesign.textSecondary),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 13,
                                color: AppDesign.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeText,
                                style: TextStyle(fontSize: 11, color: AppDesign.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (visit.property != null ||
              (isUpcoming && (visit.canCancel || visit.canReschedule))) ...[
            const SizedBox(height: 8),
            if ((visit.specialRequirements ?? '').isNotEmpty && isUpcoming) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppDesign.inputBackground.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_rounded, size: 14, color: AppDesign.iconColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        visit.specialRequirements!,
                        style: TextStyle(fontSize: 11, color: AppDesign.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                if (visit.property != null) ...[
                  Text(
                    visit.property!.formattedPrice,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppDesign.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppDesign.primaryYellow.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      visit.property!.listingTranslationKey.tr,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppDesign.primaryYellow,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (isUpcoming && (visit.canCancel || visit.canReschedule)) ...[
                  if (visit.canReschedule)
                    TextButton(
                      onPressed: onReschedule,
                      style: TextButton.styleFrom(
                        foregroundColor: AppDesign.primaryYellow,
                        side: const BorderSide(color: AppDesign.primaryYellow),
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        tapTargetSize: MaterialTapTargetSize.padded,
                      ),
                      child: Text(
                        'reschedule'.tr,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  if (visit.canReschedule && visit.canCancel) const SizedBox(width: 6),
                  if (visit.canCancel)
                    TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: AppDesign.errorRed,
                        side: const BorderSide(color: AppDesign.errorRed),
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        tapTargetSize: MaterialTapTargetSize.padded,
                      ),
                      child: Text(
                        'cancel'.tr,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(VisitStatus status) {
    Color color;
    String text;

    switch (status) {
      case VisitStatus.scheduled:
        color = AppDesign.primaryYellow;
        text = 'visit_status_scheduled'.tr;
        break;
      case VisitStatus.confirmed:
        color = AppDesign.accentGreen;
        text = 'visit_status_confirmed'.tr;
        break;
      case VisitStatus.completed:
        color = AppDesign.accentGreen;
        text = 'visit_status_completed'.tr;
        break;
      case VisitStatus.cancelled:
        color = AppDesign.errorRed;
        text = 'visit_status_cancelled'.tr;
        break;
      case VisitStatus.rescheduled:
        color = AppDesign.primaryYellow;
        text = 'visit_status_rescheduled'.tr;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}
