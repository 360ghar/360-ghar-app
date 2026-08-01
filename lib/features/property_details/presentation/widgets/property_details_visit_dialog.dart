import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/api_date_time.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';

/// Shows a dialog for scheduling a property visit with date, time, and notes.
void showBookVisitDialog(PropertyModel property, VisitsController visitsController) {
  Get.dialog<void>(_BookVisitDialog(property: property, visitsController: visitsController));
}

/// Dialog body that owns the notes [TextEditingController] in its [State] so the
/// controller is disposed only when the widget element is unmounted — not via a
/// route-Future callback that can fire while a final rebuild is still scheduled
/// (which previously caused "TextEditingController used after being disposed").
class _BookVisitDialog extends StatefulWidget {
  final PropertyModel property;
  final VisitsController visitsController;

  const _BookVisitDialog({required this.property, required this.visitsController});

  @override
  State<_BookVisitDialog> createState() => _BookVisitDialogState();
}

class _BookVisitDialogState extends State<_BookVisitDialog> {
  late final TextEditingController _notesController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    final now = DateTime.now();
    _selectedDate = now.add(const Duration(days: 1));
    _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _book() async {
    final visitDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (visitDateTime.isBefore(DateTime.now())) {
      AppToast.warning('invalid_time'.tr, 'select_future_datetime'.tr);
      return;
    }

    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

    final didBook = await widget.visitsController.bookVisit(
      widget.property,
      visitDateTime,
      notes: notes,
    );
    if (didBook && (Get.isDialogOpen ?? false)) {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppDesign.surface,
      title: Text('schedule_visit'.tr, style: TextStyle(color: AppDesign.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'schedule_visit_to'.trParams({'property': widget.property.title}),
            style: TextStyle(fontSize: 16, color: AppDesign.textSecondary),
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today, color: AppDesign.primaryYellow),
            title: Text('date'.tr, style: TextStyle(color: AppDesign.textPrimary)),
            subtitle: Text(
              formatDisplayDate(_selectedDate),
              style: TextStyle(color: AppDesign.textSecondary),
            ),
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().add(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time, color: AppDesign.primaryYellow),
            title: Text('time'.tr, style: TextStyle(color: AppDesign.textPrimary)),
            subtitle: Text(
              _selectedTime.format(context),
              style: TextStyle(color: AppDesign.textSecondary),
            ),
            onTap: () async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
              );
              if (picked != null) {
                setState(() => _selectedTime = picked);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
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
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text('cancel'.tr, style: TextStyle(color: AppDesign.textSecondary)),
        ),
        Obx(
          () => ElevatedButton(
            onPressed: widget.visitsController.isBookingVisit.value ? null : _book,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppDesign.primaryYellow,
              foregroundColor: AppDesign.buttonText,
            ),
            child: widget.visitsController.isBookingVisit.value
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
    );
  }
}
