import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/bootstrap/app_bootstrap.dart';
import 'package:ghar360/core/bootstrap/app_effects.dart';
import 'package:ghar360/core/bootstrap/provider_policy.dart';
import 'package:ghar360/core/controllers/localization_controller.dart';
import 'package:ghar360/core/controllers/theme_controller.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/firebase/analytics_service.dart';
import 'package:ghar360/core/firebase/firebase_initializer.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/routes/app_pages.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/null_check_trap.dart';
import 'package:ghar360/core/utils/webview_helper.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/offline_banner.dart';
import 'package:ghar360/core/widgets/paper/paper_vignette.dart';
import 'package:ghar360/features/auth/presentation/controllers/profile_completion_controller.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';

void main() async {
  runZonedGuarded(
    () async {
      final launchTimer = Stopwatch()..start();
      WidgetsFlutterBinding.ensureInitialized();

      final bootstrap = await bootstrapAppCore();
      if (!bootstrap.ok) {
        // Always paint a Flutter frame so the native splash is dismissed and
        // the user sees a recoverable error instead of a frozen logo screen.
        runApp(
          BootstrapErrorApp(
            error: bootstrap.errorMessage ?? 'Unknown startup error',
            failure: bootstrap.failure ?? BootstrapFailure.connection,
          ),
        );
        return;
      }

      _runReadyApp(bootstrap.database!, launchTimer);
    },
    (error, stack) {
      // Always surface uncaught startup/runtime errors — DebugLogger may not be ready.
      debugPrint('Uncaught zone error: ${error.runtimeType}\n$stack');

      // One-time first null-check trap capture for unhandled async errors
      if (error.toString().contains('Null check operator used on a null value')) {
        NullCheckTrap.capture(error, stack, source: 'zone');
      }
      // Report to Crashlytics if available
      if (FirebaseInitializer.isFirebaseReady) {
        try {
          unawaited(
            FirebaseCrashlytics.instance
                .recordError(error.runtimeType.toString(), stack, fatal: true)
                .catchError((Object _) {}),
          );
        } catch (_) {
          // Crashlytics may not be initialized yet
        }
      }
    },
  );
}

/// The first successful launch and a recovered launch install the same owners.
void _runReadyApp(AppDatabase database, Stopwatch launchTimer) {
  FlutterError.onError = (details) {
    NullCheckTrap.captureFlutterError(details);
    if (FirebaseInitializer.isFirebaseReady) {
      try {
        unawaited(
          FirebaseCrashlytics.instance
              .recordError(
                details.exception.runtimeType.toString(),
                details.stack ?? StackTrace.current,
                fatal: true,
              )
              .catchError((Object _) {}),
        );
      } catch (_) {
        // Monitoring must not interrupt rendering.
      }
    }
    FlutterError.presentError(
      FlutterErrorDetails(
        exception: details.exception.runtimeType.toString(),
        stack: details.stack,
        library: details.library,
      ),
    );
  };
  runApp(MyApp(database: database));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    launchTimer.stop();
    DebugLogger.initialize();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge).catchError((
        Object error,
        StackTrace stack,
      ) {
        DebugLogger.warning('System UI setup failed', error.runtimeType, stack);
      }),
    );
    WebViewHelper.ensureInitialized();
    AnalyticsService.appLaunchComplete(durationMs: launchTimer.elapsedMilliseconds);
  });
}

/// Minimal error shell with no session dependencies so startup failures
/// always replace the native splash with a recoverable UI.
class BootstrapErrorApp extends StatefulWidget {
  const BootstrapErrorApp({
    super.key,
    required this.error,
    this.failure = BootstrapFailure.connection,
    this.locale,
    this.showDevHelp = kDebugMode,
    this.retryBootstrap,
  });

  final String error;
  final BootstrapFailure failure;
  final Locale? locale;

  /// Shows build-tool instructions and the raw error dump. Defaults to
  /// [kDebugMode]; overridable only so the release rendering stays testable
  /// (the test process always runs with `kDebugMode == true`).
  final bool showDevHelp;
  final Future<void> Function()? retryBootstrap;

  @override
  State<BootstrapErrorApp> createState() => _BootstrapErrorAppState();
}

class _BootstrapErrorAppState extends State<BootstrapErrorApp> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await (widget.retryBootstrap ?? _retryBootstrapFromError)();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations(
      widget.locale ?? WidgetsBinding.instance.platformDispatcher.locale,
    );
    final messageKey = switch (widget.failure) {
      BootstrapFailure.storage => 'startup_storage_error',
      BootstrapFailure.configuration => 'startup_configuration_error',
      BootstrapFailure.connection => 'startup_connection_error',
    };
    return MaterialApp(
      locale: widget.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      theme: AppDesignTheme.light(),
      darkTheme: AppDesignTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: StateBlock(
              scene: widget.failure == BootstrapFailure.connection
                  ? PaperScene.offline
                  : PaperScene.error,
              seed: 'page',
              title: l10n.text('startup_failed'),
              message: widget.showDevHelp
                  ? 'The app could not finish startup.\n\n'
                        'Local dev:\n'
                        '1) Fill .env.development\n'
                        '2) dart run tool/sync_dev_env.dart\n'
                        '3) flutter run\n\n'
                        'Or: ./tool/run_with_env.sh'
                  : l10n.text(messageKey),
              detail: widget.showDevHelp
                  ? SizedBox(
                      width: double.infinity,
                      child: ColoredBox(
                        color: context.design.raised,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            widget.error,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: context.design.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
              actionLabel: l10n.text('retry'),
              actionIcon: KnifeIcon.retry,
              onAction: _retrying ? null : _retry,
              identifier: 'qa.bootstrap.error',
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _retryBootstrapFromError() async {
  final launchTimer = Stopwatch()..start();
  final result = await bootstrapAppCore();
  if (result.ok) {
    _runReadyApp(result.database!, launchTimer);
  } else {
    runApp(
      BootstrapErrorApp(
        error: result.errorMessage ?? 'Unknown startup error',
        failure: result.failure ?? BootstrapFailure.connection,
      ),
    );
  }
}

/// Owns the database opened by bootstrap. Settings have one provider owner.
class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.database});
  final AppDatabase database;

  @override
  Widget build(BuildContext context) => ProviderScope(
    retry: noProviderRetry,
    overrides: [
      ownedAppDatabaseOverride(database),
      profilePurposeChangedProvider.overrideWith(
        (ref) => (purpose) {
          final filters = ref.read(propertyFiltersProvider).forPage(PageType.discover);
          unawaited(
            ref
                .read(propertyFiltersProvider.notifier)
                .update(PageType.discover, filters.copyWith(purpose: purpose)),
          );
        },
      ),
    ],
    child: const _Application(),
  );
}

class _Application extends ConsumerWidget {
  const _Application();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider.select((settings) => settings.flutterMode));
    final locale = ref.watch(localizationProvider.select((settings) => settings.locale));
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: '360 Ghar',
      routerConfig: router,
      builder: (context, child) => AppToastHost(
        child: OfflineBanner(child: AppEffects(child: child ?? const SizedBox.shrink())),
      ),
      theme: AppDesignTheme.light(),
      darkTheme: AppDesignTheme.dark(),
      themeMode: theme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}
