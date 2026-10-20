import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/bug_report_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/routes/route_policy.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/paper/paper_vignette.dart';
import 'package:ghar360/features/assistant/presentation/views/assistant_view.dart';
import 'package:ghar360/features/auth/data/models/auth_flow_args.dart';
import 'package:ghar360/features/auth/presentation/views/forgot_password_view.dart';
import 'package:ghar360/features/auth/presentation/views/login_view.dart';
import 'package:ghar360/features/auth/presentation/views/phone_entry_view.dart';
import 'package:ghar360/features/auth/presentation/views/profile_completion_view.dart';
import 'package:ghar360/features/auth/presentation/views/set_password_view.dart';
import 'package:ghar360/features/auth/presentation/views/signup_view.dart';
import 'package:ghar360/features/dashboard/presentation/views/dashboard_view.dart';
import 'package:ghar360/features/discover/presentation/views/discover_view.dart';
import 'package:ghar360/features/explore/presentation/views/explore_view.dart';
import 'package:ghar360/features/likes/presentation/views/likes_view.dart';
import 'package:ghar360/features/profile/presentation/views/about_view.dart';
import 'package:ghar360/features/profile/presentation/views/edit_profile_view.dart';
import 'package:ghar360/features/profile/presentation/views/feedback_view.dart';
import 'package:ghar360/features/profile/presentation/views/help_view.dart';
import 'package:ghar360/features/profile/presentation/views/policy_page_view.dart';
import 'package:ghar360/features/profile/presentation/views/preferences_view.dart';
import 'package:ghar360/features/profile/presentation/views/privacy_view.dart';
import 'package:ghar360/features/profile/presentation/views/profile_view.dart';
import 'package:ghar360/features/property_details/presentation/views/property_details_view.dart';
import 'package:ghar360/features/splash/presentation/controllers/splash_controller.dart';
import 'package:ghar360/features/splash/presentation/views/splash_view.dart';
import 'package:ghar360/features/tools/presentation/views/area_converter_view.dart';
import 'package:ghar360/features/tools/presentation/views/capital_gains_view.dart';
import 'package:ghar360/features/tools/presentation/views/carpet_area_view.dart';
import 'package:ghar360/features/tools/presentation/views/document_checklist_view.dart';
import 'package:ghar360/features/tools/presentation/views/emi_calculator_view.dart';
import 'package:ghar360/features/tools/presentation/views/loan_eligibility_view.dart';
import 'package:ghar360/features/tools/presentation/views/tools_view.dart';
import 'package:ghar360/features/tour/presentation/views/tour_view.dart';
import 'package:ghar360/features/visits/presentation/views/visits_view.dart';
import 'package:ghar360/root.dart';

/// Stable router identity: authentication changes refresh redirects without
/// rebuilding branch navigators or losing their scroll/map state.
final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(debugLabel: 'root'),
);

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authProvider.select((state) => state.status), (_, _) => refresh.changed());
  ref.listen(onboardingProvider.select((state) => state.completed), (_, _) => refresh.changed());
  final router = GoRouter(
    navigatorKey: ref.watch(rootNavigatorKeyProvider),
    initialLocation: '/',
    overridePlatformDefaultLocation: !kIsWeb,
    refreshListenable: refresh,
    redirect: (context, state) {
      // Normalize transient route payloads before auth redirects can discard
      // `extra`. Query parameters retain only validated destination data.
      if (state.uri.path == AppRoutes.tour && state.uri.queryParameters['url'] == null) {
        final extra = state.extra;
        final url = extra is String
            ? extra
            : extra is Map
            ? extra['url']?.toString() ?? extra['tourUrl']?.toString()
            : null;
        final route = tourRouteLocation(
          url,
          title: extra is Map ? extra['title']?.toString() : null,
        );
        if (route != null) return route;
      }
      if (state.uri.path == AppRoutes.propertyDetails &&
          state.extra is PropertyModel &&
          state.uri.queryParameters['id'] == null) {
        return Uri(
          path: AppRoutes.propertyDetails,
          queryParameters: {'id': '${(state.extra as PropertyModel).id}'},
        ).toString();
      }
      return authRedirect(
        status: ref.read(authProvider).status,
        onboardingComplete: ref.read(onboardingProvider).completed,
        location: state.uri,
      );
    },
    errorBuilder: (context, state) => const RouteNotFoundView(),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Root()),
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashView()),
      GoRoute(path: AppRoutes.phoneEntry, builder: (_, _) => const PhoneEntryView()),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, state) =>
            LoginView(args: state.extra is AuthFlowArgs ? state.extra as AuthFlowArgs : null),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (_, state) =>
            SignUpView(args: state.extra is AuthFlowArgs ? state.extra as AuthFlowArgs : null),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, state) =>
            ForgotPasswordView(identifier: state.extra is String ? state.extra as String : null),
      ),
      GoRoute(
        path: AppRoutes.setPassword,
        builder: (_, _) => Consumer(
          builder: (_, ref, _) =>
              SetPasswordView(key: ValueKey(ref.watch(storageScopeProvider).accountId)),
        ),
      ),
      GoRoute(
        path: AppRoutes.profileCompletion,
        builder: (_, _) => Consumer(
          builder: (_, ref, _) =>
              ProfileCompletionView(key: ValueKey(ref.watch(storageScopeProvider).accountId)),
        ),
      ),
      GoRoute(path: AppRoutes.dashboard, redirect: (_, _) => AppRoutes.discover),
      StatefulShellRoute(
        navigatorContainerBuilder: heroSafeBranchContainer,
        builder: (_, _, navigationShell) => DashboardView(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.discover, builder: (_, _) => const DiscoverView())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.explore, builder: (_, _) => const ExploreView())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.likes, builder: (_, _) => const LikesView())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.visits, builder: (_, _) => const VisitsView())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.profile, builder: (_, _) => const ProfileView())],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.propertyDetails,
        builder: (_, state) {
          final property = state.extra is PropertyModel ? state.extra as PropertyModel : null;
          final id = property?.id ?? positivePropertyId(state.uri.queryParameters['id']);
          return id == null
              ? const RouteNotFoundView()
              : PropertyDetailsView(propertyId: id, initialProperty: property);
        },
      ),
      for (final path in [AppRoutes.propertyShortLink, AppRoutes.propertyDeepLink])
        GoRoute(
          path: path,
          builder: (_, state) {
            final id = positivePropertyId(state.pathParameters['id']);
            return id == null ? const RouteNotFoundView() : PropertyDetailsView(propertyId: id);
          },
        ),
      GoRoute(
        path: AppRoutes.tour,
        builder: (_, state) {
          final extra = state.extra;
          final url =
              state.uri.queryParameters['url'] ??
              (extra is String
                  ? extra
                  : extra is Map
                  ? extra['url']?.toString() ?? extra['tourUrl']?.toString()
                  : null);
          final title =
              state.uri.queryParameters['title'] ??
              (extra is Map ? extra['title']?.toString() : null);
          return url == null ? const RouteNotFoundView() : TourView(url: url, title: title);
        },
      ),
      GoRoute(
        path: AppRoutes.assistant,
        builder: (_, state) => AssistantView(
          conversationId: positivePropertyId(state.uri.queryParameters['conversation']),
        ),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (_, _) => Consumer(
          builder: (_, ref, _) =>
              EditProfileView(key: ValueKey(ref.watch(storageScopeProvider).accountId)),
        ),
      ),
      GoRoute(path: AppRoutes.preferences, builder: (_, _) => const PreferencesView()),
      GoRoute(path: AppRoutes.privacy, builder: (_, _) => const PrivacyView()),
      GoRoute(path: AppRoutes.help, builder: (_, _) => const HelpView()),
      GoRoute(
        path: AppRoutes.feedback,
        builder: (_, state) => Consumer(
          builder: (_, ref, _) => FeedbackView(
            key: ValueKey(ref.watch(storageScopeProvider).accountId),
            initialBugType: state.extra is BugType ? state.extra as BugType : BugType.uiBug,
          ),
        ),
      ),
      GoRoute(
        path: '/policy/:slug',
        builder: (context, state) {
          final slug = state.pathParameters['slug']!;
          final titleKey = const {
            'terms-of-service': 'privacy_terms_of_service_title',
            'privacy-policy': 'privacy_policy_item_title',
            'content-guidelines': 'privacy_content_guidelines_title',
            'content-takedown-policy': 'privacy_content_takedown_title',
            'grievance-redressal-mechanism': 'privacy_grievance_redressal_title',
          }[slug];
          return titleKey == null
              ? const RouteNotFoundView()
              : PolicyPageView(uniqueName: slug, titleText: context.l10n.text(titleKey));
        },
      ),
      GoRoute(path: AppRoutes.about, builder: (_, _) => const AboutView()),
      GoRoute(path: AppRoutes.tools, builder: (_, _) => const ToolsView()),
      GoRoute(path: AppRoutes.areaConverter, builder: (_, _) => const AreaConverterView()),
      GoRoute(path: AppRoutes.loanEligibility, builder: (_, _) => const LoanEligibilityView()),
      GoRoute(path: AppRoutes.emiCalculator, builder: (_, _) => const EmiCalculatorView()),
      GoRoute(path: AppRoutes.carpetArea, builder: (_, _) => const CarpetAreaView()),
      GoRoute(path: AppRoutes.documentChecklist, builder: (_, _) => const DocumentChecklistView()),
      GoRoute(path: AppRoutes.capitalGains, builder: (_, _) => const CapitalGainsView()),
    ],
  );
  // Account identity, not token refresh or profile edits, refreshes keyed forms.
  ref.listen(storageScopeProvider.select((scope) => scope.accountId), (_, _) => refresh.changed());
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// The shell's branch container: go_router's `indexedStack` container
/// (inactive branches stay mounted and offstage, with tickers off) plus
/// [HeroMode], so a photo shown in two tabs under the same hero tag never
/// clashes when a route is pushed over the shell.
Widget heroSafeBranchContainer(
  BuildContext context,
  StatefulNavigationShell navigationShell,
  List<Widget> children,
) => IndexedStack(
  index: navigationShell.currentIndex,
  children: [
    for (final (index, child) in children.indexed)
      Offstage(
        offstage: index != navigationShell.currentIndex,
        child: TickerMode(
          enabled: index == navigationShell.currentIndex,
          child: HeroMode(enabled: index == navigationShell.currentIndex, child: child),
        ),
      ),
  ],
);

class _RouterRefresh extends ChangeNotifier {
  void changed() => notifyListeners();
}

class RouteNotFoundView extends StatelessWidget {
  const RouteNotFoundView({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: StateBlock(
      scene: PaperScene.notFound,
      seed: 'route',
      title: context.l10n.text('page_not_found_title'),
      message: context.l10n.text('page_not_found'),
      actionLabel: context.l10n.text('go_home'),
      actionIcon: KnifeIcon.home,
      onAction: () => context.go(AppRoutes.discover),
      identifier: 'qa.state.not_found',
    ),
  );
}
