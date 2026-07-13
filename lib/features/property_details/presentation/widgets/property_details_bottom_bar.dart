import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_visit_dialog.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';

/// Sticky conversion bar: compact price + schedule CTA (or scheduled banner).
class PropertyDetailsBottomBar extends StatelessWidget {
  const PropertyDetailsBottomBar({
    super.key,
    required this.property,
    required this.visitsController,
  });

  final PropertyModel property;
  final VisitsController visitsController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      VisitModel? scheduledVisit;
      for (final v in visitsController.upcomingVisitsList) {
        if (v.propertyId == property.id) {
          scheduledVisit = v;
          break;
        }
      }

      final DateTime? scheduledDate = property.userNextVisitDate ?? scheduledVisit?.scheduledDate;
      final bool alreadyScheduled = property.userHasScheduledVisit || scheduledDate != null;

      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppDesign.surface,
          border: Border(
            top: BorderSide(color: AppDesign.primaryYellow.withValues(alpha: 0.55), width: 0.8),
          ),
          boxShadow: [
            BoxShadow(color: AppDesign.shadowColor, blurRadius: 12, offset: const Offset(0, -4)),
          ],
        ),
        child: alreadyScheduled
            ? _ScheduledBanner(
                scheduledDate: scheduledDate,
                visit: scheduledVisit,
                visitsController: visitsController,
              )
            : _ScheduleRow(property: property, visitsController: visitsController),
      );
    });
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.property, required this.visitsController});

  final PropertyModel property;
  final VisitsController visitsController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'price'.tr,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppDesign.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                property.formattedPrice,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppDesign.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: ElevatedButton(
            key: const ValueKey('qa.property_details.schedule_visit'),
            onPressed: () => showBookVisitDialog(context, property, visitsController),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shadowColor: AppDesign.transparent,
              backgroundColor: AppDesign.primaryYellow,
              foregroundColor: AppDesign.buttonText,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.button + 2),
                side: BorderSide(color: AppDesign.primaryYellowDark.withValues(alpha: 0.45)),
              ),
            ),
            child: Text(
              'schedule_visit'.tr,
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppDesign.buttonText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScheduledBanner extends StatelessWidget {
  const _ScheduledBanner({
    required this.scheduledDate,
    required this.visit,
    required this.visitsController,
  });

  final DateTime? scheduledDate;
  final VisitModel? visit;
  final VisitsController visitsController;

  String _formatDateTime(BuildContext context, DateTime date) {
    final datePart =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
    final timePart = TimeOfDay.fromDateTime(date).format(context);
    return '$datePart · $timePart';
  }

  void _openVisitsTab() {
    // Return to dashboard shell (if stacked over it) then switch tab.
    if (Get.isRegistered<DashboardController>()) {
      if (Get.key.currentState?.canPop() ?? false) {
        Get.until((route) => route.settings.name == AppRoutes.dashboard || route.isFirst);
      }
      Get.find<DashboardController>().changeTab(DashboardController.visitsTab);
    } else {
      Get.offAllNamed(AppRoutes.dashboard);
    }
  }

  void _showReschedule(BuildContext context) {
    final existing = visit;
    if (existing == null || scheduledDate == null) {
      _openVisitsTab();
      return;
    }

    final now = DateTime.now();
    DateTime selectedDate = scheduledDate!.isBefore(now) ? now : scheduledDate!;
    TimeOfDay selectedTime = scheduledDate!.isBefore(now)
        ? TimeOfDay.fromDateTime(now.add(const Duration(hours: 1)))
        : TimeOfDay.fromDateTime(scheduledDate!);
    var isLoading = false;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppDesign.surface,
            title: Text('reschedule_visit'.tr, style: TextStyle(color: AppDesign.textPrimary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${'reschedule_visit_to_prefix'.tr} ${existing.propertyTitle}',
                  style: TextStyle(fontSize: 16, color: AppDesign.textSecondary),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: AppDesign.primaryYellow),
                  title: Text('date'.tr, style: TextStyle(color: AppDesign.textPrimary)),
                  subtitle: Text(
                    '${selectedDate.day.toString().padLeft(2, '0')}/'
                    '${selectedDate.month.toString().padLeft(2, '0')}/'
                    '${selectedDate.year}',
                    style: TextStyle(color: AppDesign.textSecondary),
                  ),
                  onTap: isLoading
                      ? null
                      : () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (picked != null) {
                            setState(() => selectedDate = picked);
                          }
                        },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time, color: AppDesign.primaryYellow),
                  title: Text('time'.tr, style: TextStyle(color: AppDesign.textPrimary)),
                  subtitle: Text(
                    selectedTime.format(context),
                    style: TextStyle(color: AppDesign.textSecondary),
                  ),
                  onTap: isLoading
                      ? null
                      : () async {
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setState(() => selectedTime = picked);
                          }
                        },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Get.back(),
                child: Text('cancel'.tr, style: TextStyle(color: AppDesign.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final newDateTime = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                        if (newDateTime.isBefore(DateTime.now())) {
                          AppToast.warning('invalid_time'.tr, 'select_future_datetime'.tr);
                          return;
                        }
                        setState(() => isLoading = true);
                        final success = await visitsController.rescheduleVisit(
                          existing.id.toString(),
                          newDateTime,
                        );
                        if (success && (Get.isDialogOpen ?? false)) {
                          Get.back();
                        } else {
                          setState(() => isLoading = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesign.primaryYellow,
                  foregroundColor: AppDesign.buttonText,
                ),
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppDesign.buttonText),
                        ),
                      )
                    : Text('reschedule'.tr),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = scheduledDate != null
        ? '${'visit_scheduled'.tr}: ${_formatDateTime(context, scheduledDate!)}'
        : 'visit_scheduled'.tr;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: AppDesign.inputBackground,
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            border: Border.all(color: AppDesign.accentGreen.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppDesign.accentGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppDesign.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('qa.property_details.view_visits'),
                onPressed: _openVisitsTab,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppDesign.textPrimary,
                  side: BorderSide(color: AppDesign.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('view_visits'.tr),
              ),
            ),
            if (visit != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  key: const ValueKey('qa.property_details.reschedule_visit'),
                  onPressed: () => _showReschedule(context),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppDesign.primaryYellow,
                    foregroundColor: AppDesign.buttonText,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('reschedule'.tr),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
