import 'dart:async';

import 'package:flutter/material.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/firebase/firebase_initializer.dart';
import 'package:ghar360/core/firebase/push_notifications_service.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/core/providers/deep_link_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/routes/app_pages.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/routes/route_policy.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/widgets/common/app_update_host.dart';
import 'package:ghar360/features/properties/application/property_location.dart';

/// Owns effects that require the active app and route, not a retained tab.
class AppEffects extends ConsumerStatefulWidget {
  const AppEffects({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AppEffects> createState() => _AppEffectsState();
}

class _AppEffectsState extends ConsumerState<AppEffects> with WidgetsBindingObserver {
  late final GoRouter _router;
  PageType? _visiblePage;
  bool _foreground = true;
  bool _firebaseReady = false;

  /// Push permission is asked once, on the first signed-in tab, never over
  /// onboarding or sign-in.
  bool _pushReady = false;
  bool _pushAsked = false;

  static const _shellPaths = {
    AppRoutes.discover,
    AppRoutes.explore,
    AppRoutes.likes,
    AppRoutes.visits,
    AppRoutes.profile,
  };

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _router = ref.read(appRouterProvider);
    _router.routerDelegate.addListener(_routeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(deepLinkServiceProvider);
      _updateLocationVisibility();
      unawaited(_initializeNotifications());
    });
  }

  void _routeChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAskForPush();
      if (mounted) _updateLocationVisibility();
    });
  }

  void _updateLocationVisibility({bool reset = false}) {
    final page = !_foreground
        ? null
        : switch (_router.state.uri.path) {
            AppRoutes.discover => PageType.discover,
            AppRoutes.explore => PageType.explore,
            AppRoutes.likes => PageType.likes,
            _ => null,
          };
    if (!reset && page == _visiblePage) return;
    if (_visiblePage != null) {
      ref.read(propertyLocationProvider(_visiblePage!).notifier).setVisible(false);
    }
    _visiblePage = page;
    if (page != null) ref.read(propertyLocationProvider(page).notifier).setVisible(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateLocationVisibility();
  }

  Future<void> _initializeNotifications() async {
    try {
      final database = ref.read(appDatabaseProvider);
      await FirebaseInitializer.init(
        readConsent: (key) => database.readPreference<bool>(key) ?? false,
      );
      if (!mounted || !FirebaseInitializer.isFirebaseReady) return;
      setState(() => _firebaseReady = true);
      PushNotificationsService.onNotificationTap = (payload) {
        if (!mounted) return;
        final path = notificationDestination(payload);
        if (path != null && _router.state.uri.toString() != path) _router.go(path);
      };
      PushNotificationsService.onTokenRegistration = (token) async {
        if (!mounted) return;
        // A device registers for pushes only while a user is signed in.
        if (ref.read(storageScopeProvider).accountId == null) return;
        await ref.read(notificationsDatasourceProvider).registerDeviceToken(token: token);
      };
      await PushNotificationsService.initializeForegroundHandling();
      if (!mounted) return;
      _pushReady = true;
      _maybeAskForPush();
    } catch (error, stack) {
      DebugLogger.warning('Notification initialization failed', error.runtimeType, stack);
    }
  }

  void _maybeAskForPush() {
    if (_pushAsked || !_pushReady || !mounted) return;
    if (!_shellPaths.contains(_router.state.uri.path)) return;
    _pushAsked = true;
    unawaited(() async {
      try {
        final settings = await PushNotificationsService.requestUserPermission();
        if (!mounted) return;
        if (settings?.authorizationStatus == AuthorizationStatus.authorized ||
            settings?.authorizationStatus == AuthorizationStatus.provisional) {
          await PushNotificationsService.getToken();
        }
      } catch (error, stack) {
        DebugLogger.warning('Notification permission failed', error.runtimeType, stack);
      }
    }());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.routerDelegate.removeListener(_routeChanged);
    // ProviderScope disposes GPS providers. No ref access during widget teardown.
    unawaited(PushNotificationsService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(storageScopeProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateLocationVisibility(reset: true);
      });
    });
    ref.listen(oauthCallbackProvider, (previous, next) {
      if (next.hasError && previous != next) {
        AppToast.error(context.l10n.text('error'), context.l10n.text('login_error'));
      }
    });
    return AppUpdateHost(
      navigatorKey: ref.read(rootNavigatorKeyProvider),
      enabled: _firebaseReady,
      child: widget.child,
    );
  }
}
