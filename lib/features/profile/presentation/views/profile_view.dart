import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/bug_report_model.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/inline_retry_banner.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/robust_network_image.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/paper_sheet.dart';
import 'package:ghar360/core/widgets/paper/scene_header_sliver.dart';
import 'package:ghar360/core/widgets/paper/sheet_sliver.dart';
import 'package:ghar360/features/auth/data/auth_failure.dart';
import 'package:ghar360/features/profile/presentation/widgets/paper_parts.dart';

/// The Profile tab: the home scene, the account on the top sheet, then each
/// menu group as its own sheet on the sky with its title above it.
class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (user, resolving) = ref.watch(authProvider.select((s) => (s.user, s.resolving)));
    final l10n = context.l10n;
    final header = SceneHeaderSliver(
      title: l10n.text('profile'),
      scene: PaperSceneSpec.profile(),
      seed: 'profile',
    );
    return Scaffold(
      body: Semantics(
        label: l10n.text('profile'),
        identifier: 'qa.profile.screen',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = paperGutter(constraints.maxWidth, 840, min: 16);
            final bottom = MediaQuery.paddingOf(context).bottom;
            if (user == null) {
              return CustomScrollView(
                slivers: [
                  header,
                  SliverFillRemaining(
                    child: ColoredBox(
                      color: context.design.surface,
                      child: resolving
                          ? LoadingStates.profileSkeleton()
                          : ErrorStates.profileLoadError(
                              customMessage: l10n.text('no_user_data_available'),
                              onRetry: ref.read(authProvider.notifier).retryProfileLoad,
                              onSignOut: ref.read(authProvider.notifier).signOut,
                            ),
                    ),
                  ),
                ],
              );
            }
            return SkySheetsScrollView(
              header: header,
              seed: 'profile-band',
              slivers: [
                SheetSliver(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: side),
                      sliver: SliverToBoxAdapter(child: _ProfileHeader(user: user)),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: side - 16),
                      sliver: const SliverToBoxAdapter(child: _SessionBanners()),
                    ),
                  ],
                ),
                const SliverToBoxAdapter(child: SheetFoot(seed: 'profile-foot')),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 28, side, 32 + bottom),
                  sliver: SliverList.list(
                    children: [
                      _MenuGroup(
                        title: l10n.text('account_section'),
                        seed: 'profile-account',
                        items: [
                          _MenuItem(
                            icon: KnifeIcon.filter,
                            titleKey: 'my_preferences',
                            subtitleKey: 'property_preferences_filters',
                            qaKey: 'qa.profile.menu.preferences',
                            onTap: () => context.push(AppRoutes.preferences),
                          ),
                          _MenuItem(
                            icon: KnifeIcon.kite,
                            titleKey: 'assistant',
                            subtitleKey: 'assistant_subtitle',
                            qaKey: 'qa.profile.menu.assistant',
                            onTap: () => context.push(AppRoutes.assistant),
                          ),
                          _MenuItem(
                            icon: KnifeIcon.calculator,
                            titleKey: 'tools_calculators',
                            subtitleKey: 'tools_calculators_subtitle',
                            qaKey: 'qa.profile.menu.tools',
                            onTap: () => context.push(AppRoutes.tools),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      _MenuGroup(
                        title: l10n.text('support_section'),
                        seed: 'profile-support',
                        items: [
                          _MenuItem(
                            icon: KnifeIcon.shield,
                            titleKey: 'privacy_security',
                            subtitleKey: 'account_security_settings',
                            qaKey: 'qa.profile.menu.privacy',
                            onTap: () => context.push(AppRoutes.privacy),
                          ),
                          _MenuItem(
                            icon: KnifeIcon.info,
                            titleKey: 'help',
                            subtitleKey: 'get_help_contact_support',
                            qaKey: 'qa.profile.menu.help',
                            onTap: () => context.push(AppRoutes.help),
                          ),
                          _MenuItem(
                            icon: KnifeIcon.alert,
                            titleKey: 'report_a_bug',
                            subtitleKey: 'report_a_bug_subtitle',
                            qaKey: 'qa.profile.menu.report_bug',
                            onTap: () => context.push(AppRoutes.feedback, extra: BugType.uiBug),
                          ),
                          _MenuItem(
                            icon: KnifeIcon.plus,
                            titleKey: 'request_a_feature',
                            subtitleKey: 'request_a_feature_subtitle',
                            qaKey: 'qa.profile.menu.request_feature',
                            onTap: () =>
                                context.push(AppRoutes.feedback, extra: BugType.featureRequest),
                          ),
                          _MenuItem(
                            icon: KnifeIcon.home,
                            titleKey: 'about',
                            subtitleKey: 'app_version_information',
                            qaKey: 'qa.profile.menu.about',
                            onTap: () => context.push(AppRoutes.about),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const _SignOutButton(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Stale or failed profile refresh and a failed sign-out stay visible above
/// the menu, each with its own retry.
class _SessionBanners extends ConsumerWidget {
  const _SessionBanners();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (stale, error, resolving, signOutFailed) = ref.watch(
      authProvider.select(
        (s) => (
          s.stale,
          s.error,
          s.resolving,
          s.mutation.hasError && s.mutationKind == AuthMutation.signOut,
        ),
      ),
    );
    final session = ref.read(authProvider.notifier);
    return Column(
      children: [
        if (stale || error != null)
          InlineRetryBanner(
            message: context.l10n.text(
              error == null
                  ? 'network_error'
                  : authFailureMessageKey(error, fallback: 'something_went_wrong'),
            ),
            onRetry: session.retryProfileLoad,
            isLoading: resolving,
          ),
        if (signOutFailed)
          InlineRetryBanner(
            message: context.l10n.text('something_went_wrong'),
            onRetry: session.signOut,
          ),
      ],
    );
  }
}

/// The account photo, or the first letter of the name on a round mint
/// cutout lying on the sheet.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.imageUrl, required this.name, this.size = 72});
  final String imageUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final text = Theme.of(context).textTheme;
    final style = (size >= 96 ? text.displayMedium : text.displaySmall)?.copyWith(
      color: design.textPrimary,
      height: 1,
    );
    final initial = SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: design.slip,
          shape: BoxShape.circle,
          boxShadow: paperShadows(PaperElevation.low, design.shadowOn(design.surface)),
        ),
        child: Center(
          // Erode sits its capitals low in the line box; lift the letter to
          // the optical centre of the circle.
          child: Transform.translate(
            offset: Offset(0, -(style?.fontSize ?? 0) * 0.08),
            child: Text(
              name.trim().isNotEmpty
                  ? name.trim()[0].toUpperCase()
                  : context.l10n.text('user_initial'),
              style: style,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
            ),
          ),
        ),
      ),
    );
    if (imageUrl.isEmpty) return initial;
    return RobustNetworkImageExtension.circular(
      imageUrl: imageUrl,
      radius: size / 2,
      placeholder: initial,
      errorWidget: initial,
    );
  }
}

/// Avatar, name and contact, then how complete the profile is: a cut strip
/// filled teal by width. The whole block opens Edit profile.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final design = context.design;
    final contact = [
      if (user.email?.isNotEmpty ?? false) user.email!,
      if (user.phone?.isNotEmpty ?? false) user.phone!,
    ];
    final percentage = user.profileCompletionPercentage;
    final complete = percentage >= 100;
    return Semantics(
      identifier: 'qa.profile.menu.edit_profile',
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const ValueKey('qa.profile.menu.edit_profile'),
          onTap: () => context.push(AppRoutes.editProfile),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ProfileAvatar(imageUrl: user.profileImage ?? '', name: user.name),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name.isNotEmpty ? user.name : context.l10n.text('user_name'),
                            style: text.headlineMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          for (final line in contact)
                            Text(
                              line,
                              style: text.bodyMedium?.copyWith(color: design.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    PaperIcon(KnifeIcon.chevronRight, color: design.textTertiary, size: 20),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  complete
                      ? context.l10n.text('profile_complete')
                      : context.l10n.text(
                          'profile_complete_percent',
                          params: {'percent': '$percentage'},
                        ),
                  style: text.labelLarge?.copyWith(
                    color: complete ? design.success : design.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                CutStrip(
                  key: const ValueKey('qa.profile.completion'),
                  value: percentage / 100,
                  seed: 'profile-completion',
                  color: complete ? design.success : design.accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
    required this.qaKey,
    required this.onTap,
  });
  final KnifeIcon icon;
  final String titleKey;
  final String subtitleKey;
  final String qaKey;
  final VoidCallback onTap;
}

/// A group title on the sky over its own sheet of rows: bare teal icon,
/// title, one line, chevron. Rows are set apart by space, not rules.
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.title, required this.seed, required this.items});
  final String title;
  final String seed;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 10),
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
        PaperSheet(
          seed: seed,
          elevation: PaperElevation.low,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (final item in items)
                  Semantics(
                    identifier: item.qaKey,
                    child: ListTile(
                      key: ValueKey<String>(item.qaKey),
                      onTap: item.onTap,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      // Icon and chevron sit level with the title line, also when
                      // large text wraps the row.
                      titleAlignment: ListTileTitleAlignment.top,
                      leading: PaperIcon(item.icon, color: design.accent, size: 22),
                      title: Text(context.l10n.text(item.titleKey)),
                      subtitle: Text(context.l10n.text(item.subtitleKey)),
                      trailing: PaperIcon(
                        KnifeIcon.chevronRight,
                        color: design.textTertiary,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(authProvider.select((s) => s.mutation.isLoading));
    return Center(
      child: TextButton.icon(
        key: const ValueKey('qa.profile.logout'),
        onPressed: busy ? null : () => _confirmSignOut(context, ref),
        style: TextButton.styleFrom(
          foregroundColor: context.design.error,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        icon: const PaperIcon(KnifeIcon.logout, size: 20),
        label: Text(context.l10n.text('sign_out')),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.text('logout')),
        content: Text(context.l10n.text('logout_confirm_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.text('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.design.error),
            child: Text(context.l10n.text('logout')),
          ),
        ],
      ),
    );
    if (confirmed == true) await ref.read(authProvider.notifier).signOut();
  }
}
