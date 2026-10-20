import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ghar360/core/data/models/bug_report_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/profile/presentation/controllers/feedback_controller.dart';
import 'package:ghar360/features/profile/presentation/widgets/profile_sheet_page.dart';
import 'package:ghar360/features/profile/presentation/widgets/server_field_errors.dart';

class FeedbackView extends ConsumerStatefulWidget {
  const FeedbackView({super.key, this.initialBugType = BugType.uiBug});
  final BugType initialBugType;

  @override
  ConsumerState<FeedbackView> createState() => _FeedbackViewState();
}

class _FeedbackViewState extends ConsumerState<FeedbackView> {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController(),
      descriptionController = TextEditingController(),
      stepsController = TextEditingController(),
      expectedController = TextEditingController(),
      actualController = TextEditingController(),
      tagsController = TextEditingController();
  late BugType selectedBugType = widget.initialBugType;
  BugSeverity selectedSeverity = BugSeverity.medium;
  void setBugType(BugType? value) {
    if (value != null) setState(() => selectedBugType = value);
  }

  void setSeverity(BugSeverity? value) {
    if (value != null) setState(() => selectedSeverity = value);
  }

  @override
  void dispose() {
    for (final field in [
      titleController,
      descriptionController,
      stepsController,
      expectedController,
      actualController,
      tagsController,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> submitFeedback() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(_edited.clear);
    final response = await ref
        .read(feedbackProvider.notifier)
        .submitFeedback(
          type: selectedBugType,
          severity: selectedSeverity,
          title: titleController.text,
          description: descriptionController.text,
          steps: stepsController.text,
          expected: expectedController.text,
          actual: actualController.text,
          tags: tagsController.text,
        );
    if (!mounted || response == null) return;
    AppToast.success(context.l10n.text('feedback_sent'), context.l10n.text('thanks_for_feedback'));
    context.pop(response);
  }

  /// Request fields changed since the last submit; their server errors no
  /// longer apply.
  final _edited = <String>{};

  String? _serverError(Object? error, String field) =>
      _edited.contains(field) ? null : serverFieldError(context, error, field);

  @override
  Widget build(BuildContext context) {
    final operation = ref.watch(feedbackProvider);
    final error = operation.error is AppException ? operation.error as AppException : null;
    final l10n = context.l10n;
    return ProfileSheetPage(
      title: l10n.text('send_feedback'),
      identifier: 'qa.profile.feedback.screen',
      children: [
        Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.text('feedback_subtitle'),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: context.design.textSecondary),
              ),
              const SizedBox(height: 24),
              _label(l10n.text('issue_type')),
              _dropdown<BugType>(
                value: selectedBugType,
                items: BugType.values,
                onChanged: setBugType,
                itemLabel: _bugTypeLabel,
              ),
              const SizedBox(height: 20),
              _label(l10n.text('severity_label')),
              _dropdown<BugSeverity>(
                value: selectedSeverity,
                items: BugSeverity.values,
                onChanged: setSeverity,
                itemLabel: _severityLabel,
              ),
              const SizedBox(height: 20),
              _label(l10n.text('title_label')),
              _field(
                controller: titleController,
                field: 'title',
                error: error,
                hintText: l10n.text('title_hint'),
                qaKey: 'qa.profile.feedback.title_input',
                maxLength: BugReportLimits.title,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? l10n.text('title_validation') : null,
              ),
              const SizedBox(height: 20),
              _label(l10n.text('what_happened')),
              _field(
                controller: descriptionController,
                field: 'description',
                error: error,
                hintText: l10n.text('description_hint'),
                qaKey: 'qa.profile.feedback.description_input',
                maxLines: 5,
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.text('description_validation')
                    : null,
              ),
              const SizedBox(height: 20),
              _label(l10n.text('steps_to_reproduce')),
              _field(
                controller: stepsController,
                field: 'steps_to_reproduce',
                error: error,
                hintText: l10n.text('steps_hint'),
                maxLines: 4,
              ),
              const SizedBox(height: 20),
              _label(l10n.text('expected_behaviour')),
              _field(
                controller: expectedController,
                field: 'expected_behavior',
                error: error,
                hintText: l10n.text('expected_hint'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              _label(l10n.text('actual_behaviour')),
              _field(
                controller: actualController,
                field: 'actual_behavior',
                error: error,
                hintText: l10n.text('actual_hint'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              _label(l10n.text('tags_optional')),
              _field(
                controller: tagsController,
                field: 'tags',
                error: error,
                hintText: l10n.text('tags_hint'),
                helperText: l10n.text('tags_helper'),
              ),
              const SizedBox(height: 16),
              ProfileFormError(error: error, fallback: 'feedback_send_error'),
              const SizedBox(height: 12),
              Semantics(
                identifier: 'qa.profile.feedback.submit',
                child: FilledButton(
                  key: const ValueKey('qa.profile.feedback.submit'),
                  onPressed: operation.isLoading ? null : submitFeedback,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: operation.isLoading
                      ? LoadingStates.buttonSpinner(
                          color: context.design.buttonPrimaryText,
                          semanticsLabel: l10n.text('sending_feedback'),
                        )
                      : Text(l10n.text('send_feedback'), textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _field({
    required TextEditingController controller,
    required String field,
    required AppException? error,
    required String hintText,
    String? qaKey,
    String? helperText,
    String? Function(String?)? validator,
    int maxLines = 1,
    int? maxLength,
  }) => Semantics(
    identifier: qaKey,
    child: TextFormField(
      key: qaKey != null ? ValueKey<String>(qaKey) : null,
      controller: controller,
      validator: validator,
      forceErrorText: _serverError(error, field),
      onChanged: (_) {
        if (_edited.add(field)) setState(() {});
      },
      maxLines: maxLines,
      minLines: maxLines > 1 ? 3 : 1,
      inputFormatters: [if (maxLength != null) LengthLimitingTextInputFormatter(maxLength)],
      decoration: InputDecoration(hintText: hintText, helperText: helperText),
    ),
  );

  Widget _dropdown<T>({
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
    required String Function(T) itemLabel,
  }) => DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    onChanged: onChanged,
    icon: PaperIcon(KnifeIcon.chevronDown, color: context.design.textSecondary),
    items: items
        .map((item) => DropdownMenuItem<T>(value: item, child: Text(itemLabel(item))))
        .toList(),
  );

  String _bugTypeLabel(BugType type) {
    switch (type) {
      case BugType.uiBug:
        return context.l10n.text('bug_type_ui');
      case BugType.functionalityBug:
        return context.l10n.text('bug_type_functionality');
      case BugType.performanceIssue:
        return context.l10n.text('bug_type_performance');
      case BugType.crash:
        return context.l10n.text('bug_type_crash');
      case BugType.featureRequest:
        return context.l10n.text('bug_type_feature');
      case BugType.other:
        return context.l10n.text('bug_type_other');
    }
  }

  String _severityLabel(BugSeverity severity) {
    switch (severity) {
      case BugSeverity.low:
        return context.l10n.text('severity_low');
      case BugSeverity.medium:
        return context.l10n.text('severity_medium');
      case BugSeverity.high:
        return context.l10n.text('severity_high');
      case BugSeverity.critical:
        return context.l10n.text('severity_critical');
    }
  }
}
