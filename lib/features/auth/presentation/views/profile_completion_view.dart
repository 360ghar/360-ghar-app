import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/paper_vignette.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';
import 'package:ghar360/features/auth/presentation/controllers/profile_completion_controller.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_form_fields.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_premium_shell.dart';
import 'package:ghar360/features/auth/presentation/widgets/otp_input_field.dart';

class ProfileCompletionView extends ConsumerStatefulWidget {
  const ProfileCompletionView({super.key});
  @override
  ConsumerState<ProfileCompletionView> createState() => _ProfileCompletionViewState();
}

class _ProfileCompletionViewState extends ConsumerState<ProfileCompletionView> {
  final _form = GlobalKey<FormState>(), _phoneForm = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _dob = TextEditingController();
  final _phone = TextEditingController(), _otp = TextEditingController();
  DateTime? _birthDate;
  String _purpose = 'buy';
  bool _detailsDeferred = false;
  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _name.text = user?.fullName ?? '';
    _email.text = user?.email ?? '';
    _birthDate = DateTime.tryParse(user?.dateOfBirth ?? '');
    if (_birthDate != null) _dob.text = dateDisplay(_birthDate!);
  }

  @override
  void dispose() {
    for (final field in [_name, _email, _dob, _phone, _otp]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await selectBirthDate(context, _birthDate);
    if (mounted && date != null) {
      setState(() {
        _birthDate = date;
        _dob.text = dateDisplay(date);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileCompletionProvider);
    final controller = ref.read(profileCompletionProvider.notifier);
    final l = context.l10n;
    return Semantics(
      identifier: 'qa.auth.profile_completion.screen',
      child: AuthPremiumShell(
        title: l.text(state.showAddPhone ? 'add_phone_title' : 'complete_your_profile'),
        subtitle: state.showAddPhone ? l.text('add_phone_subtitle') : '',
        onBack: !state.showAddPhone && state.step > 0 && !state.loading ? controller.back : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.showAddPhone) ...[
              if (!state.phoneOtpStage)
                Form(
                  key: _phoneForm,
                  child: TextFormField(
                    controller: _phone,
                    key: const ValueKey('qa.auth.profile_completion.phone_input'),
                    keyboardType: TextInputType.phone,
                    enabled: !state.loading,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    onTap: () async {
                      final hint = await phoneNumberHint();
                      if (mounted && hint != null) _phone.text = hint;
                    },
                    validator: (value) => value?.trim().isEmpty != false
                        ? l.text('phone_required')
                        : IdentifierUtils.isPhone(value!)
                        ? null
                        : l.text('phone_invalid'),
                    decoration: InputDecoration(
                      labelText: l.text('phone_number'),
                      hintText: l.text('phone_hint'),
                    ),
                  ),
                )
              else ...[
                Text(
                  l.text('otp_sent_to', params: {'identifier': IdentifierUtils.mask(_phone.text)}),
                ),
                OtpInputField(
                  controller: _otp,
                  semanticsLabel: 'qa.auth.profile_completion.otp_input',
                  onCompleted: controller.verifyAddPhoneOtp,
                ),
                AuthResendButton(
                  countdown: state.otpCountdown,
                  loading: state.loading,
                  onPressed: controller.resendAddPhoneOtp,
                ),
              ],
              const SizedBox(height: 20),
              AuthSubmitButton(
                label: l.text(state.phoneOtpStage ? 'verify_otp' : 'send_otp'),
                loading: state.loading,
                onPressed: () {
                  if (state.phoneOtpStage) {
                    controller.verifyAddPhoneOtp(_otp.text);
                  } else if (_phoneForm.currentState?.validate() ?? false) {
                    controller.sendAddPhoneOtp(_phone.text);
                  }
                },
              ),
              Semantics(
                identifier: 'qa.auth.profile_completion.skip_phone',
                child: TextButton(
                  key: const ValueKey('qa.auth.profile_completion.skip_phone'),
                  onPressed: state.loading ? null : controller.skipAddPhone,
                  child: Text(l.text('skip_for_now')),
                ),
              ),
            ] else ...[
              LinearProgressIndicator(
                value: (state.step + 1) / 2,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 16),
              if (state.step == 0)
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      TextFormField(
                        key: const ValueKey('qa.auth.profile_completion.full_name_input'),
                        controller: _name,
                        autofillHints: const [AutofillHints.name],
                        validator: (value) =>
                            value?.trim().isNotEmpty == true ? null : l.text('full_name_required'),
                        decoration: InputDecoration(labelText: l.text('full_name')),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('qa.auth.profile_completion.email_input'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        validator: (value) => value?.trim().isEmpty != false
                            ? l.text('email_required')
                            : IdentifierUtils.isEmail(value!)
                            ? null
                            : l.text('email_invalid'),
                        decoration: InputDecoration(labelText: l.text('email_address')),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('qa.auth.profile_completion.dob_input'),
                        controller: _dob,
                        readOnly: true,
                        onTap: _selectDate,
                        validator: (_) => _birthDate == null ? l.text('dob_required') : null,
                        decoration: InputDecoration(
                          labelText: l.text('date_of_birth'),
                          hintText: l.text('dob_format_hint'),
                          suffixIcon: const Padding(
                            padding: EdgeInsets.all(12),
                            child: PaperIcon(KnifeIcon.calendar, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Text(
                  l.text('what_are_you_looking_for'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                RadioGroup<String>(
                  groupValue: _purpose,
                  onChanged: (value) {
                    if (value != null && !state.loading) setState(() => _purpose = value);
                  },
                  child: _PurposeChoices(enabled: !state.loading),
                ),
              ],
              const SizedBox(height: 20),
              AuthSubmitButton(
                identifier: 'qa.auth.profile_completion.submit',
                label: l.text(
                  state.step == 0
                      ? 'next'
                      : _detailsDeferred
                      ? 'continue_btn'
                      : 'complete',
                ),
                loading: state.loading,
                onPressed: () {
                  if (state.step == 0) {
                    if (_form.currentState?.validate() ?? false) {
                      _detailsDeferred = false;
                      controller.nextStep();
                    }
                  } else if (_detailsDeferred) {
                    controller.skipProfile(_purpose);
                  } else {
                    controller.completeProfile(
                      {'full_name': _name.text.trim(), 'date_of_birth': dateValue(_birthDate)},
                      _purpose,
                      email: _email.text,
                    );
                  }
                },
              ),
            ],
            if (!state.showAddPhone)
              Semantics(
                identifier: 'qa.auth.profile_completion.skip',
                child: TextButton(
                  key: const ValueKey('qa.auth.profile_completion.skip'),
                  onPressed: state.loading
                      ? null
                      : () {
                          if (state.step == 0) {
                            _detailsDeferred = true;
                            controller.nextStep();
                          } else {
                            controller.skipProfile(_purpose);
                          }
                        },
                  child: Text(l.text('skip_for_now')),
                ),
              ),
            AuthFormError(
              error: state.error,
              fallback: state.showAddPhone ? 'otp_verification_error' : 'profile_update_failed',
            ),
          ],
        ),
      ),
    );
  }
}

/// Buy, rent or short stay, each a paper scene: a home, a key, a PG room.
/// Three across when they fit, else one under the other with the scene at
/// the side.
class _PurposeChoices extends StatelessWidget {
  const _PurposeChoices({required this.enabled});

  final bool enabled;

  static const _scenes = {'buy': 'home', 'rent': 'key', 'short_stay': 'pg'};

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final across = constraints.maxWidth / scale >= 300;
      final cards = [
        for (final MapEntry(key: purpose, value: scene) in _scenes.entries)
          _PurposeCard(purpose: purpose, scene: scene, across: across, enabled: enabled),
      ];
      if (!across) {
        return Column(
          children: [
            for (final card in cards)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: card),
          ],
        );
      }
      // Equal heights, so the labels share one baseline.
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, card) in cards.indexed) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(child: card),
            ],
          ],
        ),
      );
    },
  );
}

/// One purpose. The scene's own card carries it; the chosen one is drawn
/// round with a teal cut edge and its label turns teal.
class _PurposeCard extends StatefulWidget {
  const _PurposeCard({
    required this.purpose,
    required this.scene,
    required this.across,
    required this.enabled,
  });

  final String purpose;
  final String scene;
  final bool across;
  final bool enabled;

  @override
  State<_PurposeCard> createState() => _PurposeCardState();
}

class _PurposeCardState extends State<_PurposeCard> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final id = 'qa.auth.profile_completion.purpose.${widget.purpose}';
    return Semantics(
      identifier: id,
      child: RawRadio<String>(
        key: ValueKey(id),
        value: widget.purpose,
        mouseCursor: WidgetStateMouseCursor.clickable,
        toggleable: false,
        focusNode: _focus,
        autofocus: false,
        groupRegistry: RadioGroup.maybeOf<String>(context),
        enabled: widget.enabled,
        builder: (context, state) {
          final chosen = state.value ?? false;
          final focused = state.states.contains(WidgetState.focused);
          final label = Text(
            context.l10n.text(widget.purpose),
            textAlign: widget.across ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: chosen ? design.accent : design.textPrimary,
              fontWeight: chosen ? FontWeight.w800 : FontWeight.w600,
            ),
          );
          final scene = PaperArtView.vignette(widget.scene, seed: 'purpose', width: 200);
          return DecoratedBox(
            decoration: ShapeDecoration(
              color: design.surface,
              shape: CutBorder(
                seed: 'purpose-${widget.purpose}',
                amp: 1.5,
                side: chosen || focused
                    ? BorderSide(color: design.accent, width: chosen ? 2 : 1)
                    : BorderSide.none,
              ),
            ),
            // The padding clears the cut and the 2 px edge.
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: widget.across
                  ? Column(
                      children: [
                        scene,
                        const SizedBox(height: 10),
                        Expanded(child: Center(child: label)),
                      ],
                    )
                  : Row(
                      children: [
                        SizedBox(width: 96, child: scene),
                        const SizedBox(width: 16),
                        Expanded(child: label),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}
