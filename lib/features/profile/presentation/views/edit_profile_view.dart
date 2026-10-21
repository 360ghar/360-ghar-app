import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/api_date_time.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_form_fields.dart';
import 'package:ghar360/features/profile/presentation/controllers/edit_profile_controller.dart';
import 'package:ghar360/features/profile/presentation/views/profile_view.dart';
import 'package:ghar360/features/profile/presentation/widgets/profile_sheet_page.dart';
import 'package:ghar360/features/profile/presentation/widgets/server_field_errors.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileView extends ConsumerStatefulWidget {
  const EditProfileView({super.key});

  @override
  ConsumerState<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends ConsumerState<EditProfileView> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(),
      emailController = TextEditingController(),
      locationController = TextEditingController();
  DateTime? dateOfBirth;

  /// Request fields the user changed since the last save; their server errors
  /// no longer apply.
  final _edited = <String>{};

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    nameController.text = user?.name ?? '';
    emailController.text = user?.email ?? '';
    locationController.text = user?.preferences.location ?? '';
    dateOfBirth = user?.dateOfBirthAsDate;
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    locationController.dispose();
    super.dispose();
  }

  void _markEdited(String field) {
    if (_edited.add(field)) setState(() {});
  }

  Future<void> pickProfileImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const PaperIcon(KnifeIcon.camera),
              title: Text(context.l10n.text('take_photo')),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const PaperIcon(KnifeIcon.upload),
              title: Text(context.l10n.text('choose_from_gallery')),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (!mounted || file == null) return;
      final saved = await ref.read(editProfileProvider.notifier).uploadImage(file.path);
      if (mounted && saved) {
        AppToast.success(context.l10n.text('success'), context.l10n.text('profile_image_selected'));
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context.l10n.text('error'), context.l10n.text('failed_to_pick_image'));
      }
    }
  }

  Future<void> selectDateOfBirth(BuildContext context) async {
    final value = await selectBirthDate(context, dateOfBirth);
    if (mounted && value != null) {
      setState(() => dateOfBirth = value);
      _markEdited('date_of_birth');
    }
  }

  void clearDateOfBirth() {
    setState(() => dateOfBirth = null);
    _markEdited('date_of_birth');
  }

  Future<void> saveProfile() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(_edited.clear);
    final saved = await ref
        .read(editProfileProvider.notifier)
        .saveProfile(
          name: nameController.text,
          location: locationController.text,
          dateOfBirth: dateOfBirth,
        );
    if (mounted && saved) {
      AppToast.success(
        context.l10n.text('success'),
        context.l10n.text('profile_updated_successfully'),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editProfileProvider);
    final imageUrl = ref.watch(authProvider.select((value) => value.user?.profileImage)) ?? '';
    final l10n = context.l10n;
    final busy = state.saving || state.uploading;
    String? serverError(String field) =>
        _edited.contains(field) ? null : serverFieldError(context, state.error, field);
    return ProfileSheetPage(
      title: l10n.text('edit_profile'),
      identifier: 'qa.profile.edit.screen',
      maxWidth: 560,
      children: [
        Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ProfileAvatar(imageUrl: imageUrl, name: nameController.text, size: 112),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  key: const ValueKey('qa.profile.edit.pick_image'),
                  onPressed: busy ? null : pickProfileImage,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: state.uploading
                      ? LoadingStates.buttonSpinner(semanticsLabel: l10n.text('loading'))
                      : const PaperIcon(KnifeIcon.camera, size: 20),
                  label: Text(l10n.text('change_photo')),
                ),
              ),
              SheetSectionTitle(l10n.text('personal_information'), top: 20),
              const SizedBox(height: 8),
              _field(
                controller: nameController,
                label: l10n.text('full_name'),
                qaKey: 'qa.profile.edit.full_name_input',
                serverError: serverError('full_name'),
                onChanged: (_) => _markEdited('full_name'),
                enabled: !state.saving,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? l10n.text('name_required') : null,
              ),
              const SizedBox(height: 16),
              _field(
                controller: emailController,
                label: l10n.text('email_address'),
                qaKey: 'qa.profile.edit.email_input',
                keyboardType: TextInputType.emailAddress,
                enabled: false, // Email is read-only; changes require re-verification
              ),
              const SizedBox(height: 16),
              _field(
                controller: locationController,
                label: l10n.text('location'),
                qaKey: 'qa.profile.edit.location_input',
                serverError: serverError('preferences'),
                onChanged: (_) => _markEdited('preferences'),
                enabled: !state.saving,
              ),
              const SizedBox(height: 16),
              _dateOfBirth(context, serverError('date_of_birth'), state.saving),
              const SizedBox(height: 24),
              ProfileFormError(error: state.error, fallback: 'profile_update_failed'),
              const SizedBox(height: 8),
              Semantics(
                identifier: 'qa.profile.edit.save',
                child: FilledButton(
                  key: const ValueKey('qa.profile.edit.save'),
                  onPressed: busy ? null : saveProfile,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: state.saving
                      ? LoadingStates.buttonSpinner(
                          size: 20,
                          color: context.design.buttonPrimaryText,
                          semanticsLabel: l10n.text('saving'),
                        )
                      : Text(l10n.text('save_changes'), textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dateOfBirth(BuildContext context, String? error, bool saving) {
    final l10n = context.l10n;
    final value = dateOfBirth;
    return Semantics(
      identifier: 'qa.profile.edit.dob_input',
      button: true,
      child: InkWell(
        key: const ValueKey('qa.profile.edit.dob_input'),
        onTap: saving ? null : () => selectDateOfBirth(context),
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: l10n.text('date_of_birth'),
            errorText: error,
            enabled: !saving,
            suffixIcon: value == null
                ? PaperIcon(KnifeIcon.calendar, color: context.design.textSecondary)
                : IconButton(
                    tooltip: l10n.text('clear'),
                    onPressed: saving ? null : clearDateOfBirth,
                    icon: PaperIcon(KnifeIcon.close, color: context.design.textSecondary),
                  ),
          ),
          child: Text(
            value != null ? formatDisplayDate(value) : l10n.text('select_your_date_of_birth'),
            style: TextStyle(
              color: value != null ? context.design.textPrimary : context.design.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? qaKey,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? serverError,
    ValueChanged<String>? onChanged,
    bool enabled = true,
  }) => Semantics(
    identifier: qaKey,
    child: TextFormField(
      key: qaKey != null ? ValueKey<String>(qaKey) : null,
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      forceErrorText: serverError,
      onChanged: onChanged,
      enabled: enabled,
      decoration: InputDecoration(labelText: label),
    ),
  );
}
