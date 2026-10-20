import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/visits/data/visits_repository.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import 'package:ghar360/features/visits/presentation/widgets/visit_failure_message.dart';
import 'package:go_router/go_router.dart';

Future<void> showBookVisitDialog(BuildContext context, PropertyModel property) => showDialog<void>(
  context: context,
  builder: (_) => BookVisitDialog(property: property),
);

class BookVisitDialog extends ConsumerStatefulWidget {
  const BookVisitDialog({super.key, required this.property});
  final PropertyModel property;
  @override
  ConsumerState<BookVisitDialog> createState() => _BookVisitDialogState();
}

class _BookVisitDialogState extends ConsumerState<BookVisitDialog> {
  final _notes = TextEditingController();
  late DateTime _date;
  late TimeOfDay _time;
  late final StorageScope _scope;
  late final AppDatabase _database;
  Timer? _draftTimer;
  bool _dirty = false;
  bool _busy = false;
  bool _unresolved = false;
  bool _allowClose = false;
  String? _error;
  String get _draftKey => 'visit:${widget.property.id}';
  @override
  void initState() {
    super.initState();
    _date = DateTime.now().add(const Duration(days: 1));
    _time = const TimeOfDay(hour: 10, minute: 0);
    _scope = ref.read(storageScopeProvider);
    _database = ref.read(appDatabaseProvider);
    unawaited(_restore());
    _notes.addListener(_scheduleSave);
  }

  Future<void> _restore() async {
    try {
      final draft = await _database.readDraft(scope: _scope, key: _draftKey);
      if (!mounted || _dirty || draft == null) return;
      final date = DateTime.tryParse(draft['date']?.toString() ?? '')?.toLocal();
      setState(() {
        if (date != null) {
          _date = date;
          _time = TimeOfDay.fromDateTime(date);
        }
        _notes.text = draft['notes']?.toString() ?? '';
      });
    } catch (error) {
      if (mounted) setState(() => _error = visitFailureMessage(context, error));
    }
  }

  DateTime get _selectedDate =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
  Future<void> _save() => _database.writeDraft(
    scope: _scope,
    key: _draftKey,
    value: {'date': _selectedDate.toUtc().toIso8601String(), 'notes': _notes.text},
  );
  void _scheduleSave() {
    _dirty = true;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        await _save();
      } catch (error) {
        if (mounted) setState(() => _error = visitFailureMessage(context, error));
      }
    });
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _book() async {
    if (_busy || _unresolved) return;
    if (!_selectedDate.isAfter(DateTime.now())) {
      setState(() => _error = context.l10n.text('select_future_datetime'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    _draftTimer?.cancel();
    try {
      await _save();
      if (!mounted) return;
      final result = await ref
          .read(visitsProvider.notifier)
          .bookVisit(
            widget.property.id,
            _selectedDate,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (!mounted) return;
      switch (result) {
        case VisitConfirmed():
          try {
            await _database.removeDraft(scope: _scope, key: _draftKey);
          } catch (_) {}
          if (mounted) {
            _dirty = false;
            setState(() => _allowClose = true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).pop();
            });
          }
        case VisitUnresolved():
          setState(() {
            _unresolved = true;
            _error = context.l10n.text('visits_pending_help');
          });
        case VisitFailed(:final failure, :final savedAction):
          setState(() {
            _error = visitFailureMessage(context, failure);
            _unresolved = savedAction != null;
          });
      }
    } catch (error) {
      if (mounted) setState(() => _error = visitFailureMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    if (_busy) return;
    _draftTimer?.cancel();
    try {
      if (_dirty) await _save();
      if (!mounted) return;
      setState(() => _allowClose = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (error) {
      if (mounted) setState(() => _error = visitFailureMessage(context, error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowClose,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) unawaited(_close());
      },
      child: AlertDialog(
        scrollable: true,
        title: Text(context.l10n.text(_unresolved ? 'visits_request_saved' : 'schedule_visit')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.text('schedule_visit_to', params: {'property': widget.property.title}),
            ),
            const SizedBox(height: 16),
            _ChoiceSlip(
              seed: 'visit-date',
              icon: KnifeIcon.calendar,
              label: context.l10n.text('date'),
              value: MaterialLocalizations.of(context).formatMediumDate(_date),
              onTap: _busy || _unresolved
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
                      if (mounted && picked != null) {
                        setState(() => _date = picked);
                        _scheduleSave();
                      }
                    },
            ),
            const SizedBox(height: 8),
            _ChoiceSlip(
              seed: 'visit-time',
              icon: KnifeIcon.clock,
              label: context.l10n.text('time'),
              value: _time.format(context),
              onTap: _busy || _unresolved
                  ? null
                  : () async {
                      final picked = await showTimePicker(context: context, initialTime: _time);
                      if (mounted && picked != null) {
                        setState(() => _time = picked);
                        _scheduleSave();
                      }
                    },
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.text('visits_local_time'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            // The label sits above the field, so a long label wraps instead
            // of being cut inside the border.
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.text('special_requirements_label'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notes,
                    enabled: !_busy && !_unresolved,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: context.l10n.text('special_requirements_hint'),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: context.design.error),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: _busy ? null : _close, child: Text(context.l10n.text('cancel'))),
          if (_unresolved)
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go(AppRoutes.visits);
              },
              child: Text(context.l10n.text('view_visits')),
            )
          else
            FilledButton(
              onPressed: _busy ? null : _book,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(opacity: _busy ? 0 : 1, child: Text(context.l10n.text('schedule_visit'))),
                  if (_busy) LoadingStates.buttonSpinner(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A date or time choice in the dialog: a mint paper slip with a hand-cut
/// edge, the value in bold under its name, and a chevron that says it opens a
/// picker.
class _ChoiceSlip extends StatelessWidget {
  const _ChoiceSlip({
    required this.seed,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String seed;
  final KnifeIcon icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final text = Theme.of(context).textTheme;
    final shape = CutBorder(seed: seed, amp: 1.5);
    return Semantics(
      button: true,
      child: Material(
        color: design.slip,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
              child: Row(
                children: [
                  PaperIcon(icon, size: 20, color: design.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: text.labelSmall),
                        Text(value, style: text.titleMedium),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    PaperIcon(KnifeIcon.chevronDown, size: 18, color: design.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
