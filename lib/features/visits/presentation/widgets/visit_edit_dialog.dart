import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import 'package:ghar360/features/visits/presentation/widgets/visit_card.dart';
import 'package:ghar360/features/visits/presentation/widgets/visit_failure_message.dart';

Future<void> showVisitEditDialog(BuildContext context, VisitModel visit, {required bool cancel}) =>
    showDialog<void>(
      context: context,
      builder: (_) => VisitEditDialog(visit: visit, cancel: cancel),
    );

class VisitEditDialog extends ConsumerStatefulWidget {
  const VisitEditDialog({super.key, required this.visit, required this.cancel});
  final VisitModel visit;
  final bool cancel;
  @override
  ConsumerState<VisitEditDialog> createState() => _VisitEditDialogState();
}

class _VisitEditDialogState extends ConsumerState<VisitEditDialog> {
  final _reason = TextEditingController();
  late DateTime _date;
  late TimeOfDay _time;
  bool _busy = false;
  String? _validation;
  @override
  void initState() {
    super.initState();
    final existing = widget.visit.scheduledDate.toLocal();
    _date = existing.isAfter(DateTime.now())
        ? existing
        : DateTime.now().add(const Duration(days: 1));
    _time = TimeOfDay.fromDateTime(_date);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final date = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    if (widget.cancel && _reason.text.trim().isEmpty) {
      setState(() => _validation = context.l10n.text('visits_reason_required'));
      return;
    }
    if (!widget.cancel && !date.isAfter(DateTime.now())) {
      setState(() => _validation = context.l10n.text('select_future_datetime'));
      return;
    }
    setState(() {
      _busy = true;
      _validation = null;
    });
    final controller = ref.read(visitsProvider.notifier);
    final ok = widget.cancel
        ? await controller.cancelVisit(widget.visit.id, reason: _reason.text)
        : await controller.rescheduleVisit(widget.visit.id, date);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mutation = ref.watch(visitsProvider.select((state) => state.mutations[widget.visit.id]));
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        title: Text(context.l10n.text(widget.cancel ? 'cancel_visit' : 'reschedule_visit')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(visitTitle(context, widget.visit)),
            const SizedBox(height: 16),
            if (widget.cancel)
              TextField(
                controller: _reason,
                enabled: !_busy,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.l10n.text('reason_required_label'),
                  errorText: _validation,
                ),
              )
            else ...[
              ListTile(
                title: Text(context.l10n.text('date')),
                subtitle: Text(MaterialLocalizations.of(context).formatMediumDate(_date)),
                onTap: _busy
                    ? null
                    : () async {
                        final today = DateUtils.dateOnly(DateTime.now());
                        final initial = _date.isBefore(today) ? today : _date;
                        final end = today.add(const Duration(days: 30));
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: today,
                          lastDate: initial.isAfter(end) ? initial : end,
                        );
                        if (mounted && picked != null) setState(() => _date = picked);
                      },
              ),
              ListTile(
                title: Text(context.l10n.text('time')),
                subtitle: Text(_time.format(context)),
                onTap: _busy
                    ? null
                    : () async {
                        final picked = await showTimePicker(context: context, initialTime: _time);
                        if (mounted && picked != null) setState(() => _time = picked);
                      },
              ),
              Text(
                context.l10n.text('visits_local_time'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.design.textSecondary),
              ),
              if (_validation != null)
                Semantics(
                  liveRegion: true,
                  child: Text(_validation!, style: TextStyle(color: context.design.error)),
                ),
            ],
            if (mutation?.hasError == true)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    visitFailureMessage(context, mutation!.error),
                    style: TextStyle(color: context.design.error),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(context.l10n.text('cancel')),
          ),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: _busy ? 0 : 1,
                  child: Text(context.l10n.text(widget.cancel ? 'yes_cancel' : 'reschedule')),
                ),
                if (_busy) LoadingStates.buttonSpinner(size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
