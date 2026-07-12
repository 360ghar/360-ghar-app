import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';

/// Shows a dialog for scheduling a property visit with date, time, and notes.
void showBookVisitDialog(
  BuildContext context,
  PropertyModel property,
  VisitsController visitsController,
) {
  final now = DateTime.now();
  DateTime selectedDate = now.add(const Duration(days: 1));
  TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
  final TextEditingController notesController = TextEditingController();

  Get.dialog(
    AlertDialog(
      backgroundColor: AppDesign.surface,
      title: Text('schedule_visit'.tr, style: TextStyle(color: AppDesign.textPrimary)),
      content: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'schedule_visit_to'.trParams({'property': property.title}),
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
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now().add(const Duration(days: 1)),
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
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (picked != null) {
                    setState(() => selectedTime = picked);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'special_requirements_label'.tr,
                  hintText: 'special_requirements_hint'.tr,
                  filled: true,
                  fillColor: AppDesign.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppDesign.border),
                  ),
                ),
                style: TextStyle(color: AppDesign.textPrimary),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text('cancel'.tr, style: TextStyle(color: AppDesign.textSecondary)),
        ),
        Obx(
          () => ElevatedButton(
            onPressed: visitsController.isBookingVisit.value
                ? null
                : () async {
                    final visitDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    if (visitDateTime.isBefore(DateTime.now())) {
                      AppToast.warning('invalid_time'.tr, 'select_future_datetime'.tr);
                      return;
                    }

                    final notes = notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim();

                    final didBook = await visitsController.bookVisit(
                      property,
                      visitDateTime,
                      notes: notes,
                    );
                    if (didBook && (Get.isDialogOpen ?? false)) {
                      Get.back();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppDesign.primaryYellow,
              foregroundColor: AppDesign.buttonText,
            ),
            child: visitsController.isBookingVisit.value
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppDesign.buttonText),
                    ),
                  )
                : Text('schedule_visit'.tr),
          ),
        ),
      ],
    ),
  ).whenComplete(notesController.dispose);
}
