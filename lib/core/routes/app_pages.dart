import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/middlewares/auth_middleware.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/routes/editorial_reveal_transition.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/features/assistant/presentation/bindings/assistant_binding.dart';
import 'package:ghar360/features/assistant/presentation/views/assistant_view.dart';
import 'package:ghar360/features/auth/presentation/bindings/auth_binding.dart';
import 'package:ghar360/features/auth/presentation/bindings/forgot_password_binding.dart';
import 'package:ghar360/features/auth/presentation/bindings/phone_entry_binding.dart';
import 'package:ghar360/features/auth/presentation/bindings/profile_completion_binding.dart';
import 'package:ghar360/features/auth/presentation/bindings/set_password_binding.dart';
import 'package:ghar360/features/auth/presentation/bindings/signup_binding.dart';
import 'package:ghar360/features/auth/presentation/views/forgot_password_view.dart';
import 'package:ghar360/features/auth/presentation/views/login_view.dart';
import 'package:ghar360/features/auth/presentation/views/phone_entry_view.dart';
import 'package:ghar360/features/auth/presentation/views/profile_completion_view.dart';
import 'package:ghar360/features/auth/presentation/views/set_password_view.dart';
import 'package:ghar360/features/auth/presentation/views/signup_view.dart';
import 'package:ghar360/features/dashboard/presentation/bindings/dashboard_binding.dart';
import 'package:ghar360/features/dashboard/presentation/views/dashboard_view.dart';
import 'package:ghar360/features/discover/presentation/bindings/discover_binding.dart';
import 'package:ghar360/features/discover/presentation/views/discover_view.dart';
import 'package:ghar360/features/explore/presentation/bindings/explore_binding.dart';
import 'package:ghar360/features/explore/presentation/views/explore_view.dart';
import 'package:ghar360/features/likes/presentation/bindings/likes_binding.dart';
import 'package:ghar360/features/likes/presentation/views/likes_view.dart';
import 'package:ghar360/features/profile/presentation/bindings/feedback_binding.dart';
import 'package:ghar360/features/profile/presentation/bindings/profile_binding.dart';
import 'package:ghar360/features/profile/presentation/controllers/preferences_controller.dart';
import 'package:ghar360/features/profile/presentation/views/about_view.dart';
import 'package:ghar360/features/profile/presentation/views/edit_profile_view.dart';
import 'package:ghar360/features/profile/presentation/views/feedback_view.dart';
import 'package:ghar360/features/profile/presentation/views/help_view.dart';
import 'package:ghar360/features/profile/presentation/views/preferences_view.dart';
import 'package:ghar360/features/profile/presentation/views/privacy_view.dart';
import 'package:ghar360/features/profile/presentation/views/profile_view.dart';
import 'package:ghar360/features/property_details/presentation/bindings/property_details_binding.dart';
import 'package:ghar360/features/property_details/presentation/views/property_details_view.dart';
import 'package:ghar360/features/splash/presentation/bindings/splash_binding.dart';
import 'package:ghar360/features/splash/presentation/views/splash_view.dart';
import 'package:ghar360/features/tools/presentation/bindings/tools_binding.dart';
import 'package:ghar360/features/tools/presentation/views/area_converter_view.dart';
import 'package:ghar360/features/tools/presentation/views/capital_gains_view.dart';
import 'package:ghar360/features/tools/presentation/views/carpet_area_view.dart';
import 'package:ghar360/features/tools/presentation/views/document_checklist_view.dart';
import 'package:ghar360/features/tools/presentation/views/emi_calculator_view.dart';
import 'package:ghar360/features/tools/presentation/views/loan_eligibility_view.dart';
import 'package:ghar360/features/tools/presentation/views/tools_view.dart';
import 'package:ghar360/features/tour/presentation/bindings/tour_binding.dart';
import 'package:ghar360/features/tour/presentation/views/tour_view.dart';
import 'package:ghar360/features/visits/presentation/bindings/visits_binding.dart';
import 'package:ghar360/features/visits/presentation/views/visits_view.dart';

// Use package import to ensure middleware classes are resolved correctly

class AppPages {
  // Default page transition settings for consistent animations
  static const Duration _defaultTransitionDuration = AppDurations.pageTransition;
  static const Curve _defaultCurve = Curves.easeOutCubic;

  // Editorial reveal: fade + subtle upward slide
  static final CustomTransition _editorialReveal = EditorialRevealTransition();
  static const Duration _editorialDuration = AppDurations.editorialReveal;

  static final routes = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
      customTransition: _editorialReveal,
      transitionDuration: _editorialDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.phoneEntry,
      page: () => const PhoneEntryView(),
      binding: PhoneEntryBinding(),
      middlewares: [GuestMiddleware()],
      customTransition: _editorialReveal,
      transitionDuration: _editorialDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
      binding: AuthBinding(),
      middlewares: [GuestMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.signup,
      page: () => const SignUpView(),
      binding: SignUpBinding(),
      middlewares: [GuestMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.forgotPassword,
      page: () => const ForgotPasswordView(),
      binding: ForgotPasswordBinding(),
      middlewares: [GuestMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.setPassword,
      page: () => const SetPasswordView(),
      binding: SetPasswordBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.profileCompletion,
      page: () => const ProfileCompletionView(),
      binding: ProfileCompletionBinding(),
      customTransition: _editorialReveal,
      transitionDuration: _editorialDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.dashboard,
      page: () => const DashboardView(),
      binding: DashboardBinding(),
      middlewares: [AuthMiddleware()],
      customTransition: _editorialReveal,
      transitionDuration: _editorialDuration,
      curve: _defaultCurve,
      children: [
        GetPage(
          name: AppRoutes.discover,
          page: () => const DiscoverView(),
          binding: DiscoverBinding(),
        ),
        GetPage(
          name: AppRoutes.explore,
          page: () => const ExploreView(),
          binding: ExploreBinding(),
        ),
        GetPage(name: AppRoutes.likes, page: () => const LikesView(), binding: LikesBinding()),
        GetPage(name: AppRoutes.visits, page: () => const VisitsView(), binding: VisitsBinding()),
        GetPage(
          name: AppRoutes.profile,
          page: () => const ProfileView(),
          binding: ProfileBinding(),
        ),
        GetPage(
          name: AppRoutes.assistant,
          page: () => const AssistantView(),
          binding: AssistantBinding(),
        ),
      ],
    ),
    GetPage(
      name: AppRoutes.propertyDetails,
      page: () => const PropertyDetailsView(),
      binding: PropertyDetailsBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    // Deep link routes - NO AuthMiddleware to allow public access from shared links
    GetPage(
      name: AppRoutes.propertyShortLink, // /p/:id
      page: () => const PropertyDetailsView(),
      binding: PropertyDetailsBinding(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.propertyDeepLink, // /property/:id
      page: () => const PropertyDetailsView(),
      binding: PropertyDetailsBinding(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.editProfile,
      page: () => const EditProfileView(),
      binding: ProfileBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.tour,
      page: () => const TourView(),
      binding: TourBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.zoom,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.preferences,
      page: () => const PreferencesView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<PreferencesController>(() => PreferencesController());
      }),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.privacy,
      page: () => const PrivacyView(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.help,
      page: () => const HelpView(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.feedback,
      page: () => const FeedbackView(),
      binding: FeedbackBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.about,
      page: () => const AboutView(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    // Tools and calculators
    GetPage(
      name: AppRoutes.tools,
      page: () => const ToolsView(),
      binding: ToolsBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.areaConverter,
      page: () => const AreaConverterView(),
      binding: AreaConverterBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.loanEligibility,
      page: () => const LoanEligibilityView(),
      binding: LoanEligibilityBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.emiCalculator,
      page: () => const EmiCalculatorView(),
      binding: EmiCalculatorBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.carpetArea,
      page: () => const CarpetAreaView(),
      binding: CarpetAreaBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.documentChecklist,
      page: () => const DocumentChecklistView(),
      binding: DocumentChecklistBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
    GetPage(
      name: AppRoutes.capitalGains,
      page: () => const CapitalGainsView(),
      binding: CapitalGainsBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: _defaultTransitionDuration,
      curve: _defaultCurve,
    ),
  ];
}
