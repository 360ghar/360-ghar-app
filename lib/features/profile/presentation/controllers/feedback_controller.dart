import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/bug_report_model.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/features/auth/data/auth_failure.dart';
import 'package:ghar360/features/profile/data/support_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => SupportRepository(apiClient: ref.watch(apiClientProvider)),
);
final feedbackPackageInfoProvider = Provider<Future<PackageInfo?> Function()>(
  (ref) => () async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      return null;
    }
  },
);
final feedbackProvider = NotifierProvider.autoDispose<FeedbackController, AsyncValue<void>>(
  FeedbackController.new,
);

class FeedbackController extends Notifier<AsyncValue<void>> {
  int _generation = 0;
  @override
  AsyncValue<void> build() {
    ref.watch(authProvider.select((value) => value.user?.supabaseUserId));
    _generation++;
    ref.onDispose(() {
      _generation++;
    });
    return const AsyncData(null);
  }

  Future<BugReportResponse?> submitFeedback({
    required BugType type,
    required BugSeverity severity,
    required String title,
    required String description,
    String steps = '',
    String expected = '',
    String actual = '',
    String tags = '',
  }) async {
    if (state.isLoading) return null;
    final repository = ref.read(supportRepositoryProvider);
    final packageInfo = ref.read(feedbackPackageInfoProvider);
    final generation = _generation;
    bool current() => ref.mounted && generation == _generation;
    state = const AsyncLoading();
    try {
      final info = await packageInfo();
      if (!current()) return null;
      final fullVersion = info == null
          ? null
          : '${info.version}${info.buildNumber.isEmpty ? '' : '+${info.buildNumber}'}';
      // `app_version` is at most 50 characters (`BugReportCreate`); a longer value is a 422.
      final version = fullVersion != null && fullVersion.length > BugReportLimits.appVersion
          ? fullVersion.substring(0, BugReportLimits.appVersion)
          : fullVersion;
      final platform = kIsWeb
          ? 'Web'
          : switch (defaultTargetPlatform) {
              TargetPlatform.android => 'Android',
              TargetPlatform.iOS => 'iOS',
              TargetPlatform.macOS => 'macOS',
              TargetPlatform.windows => 'Windows',
              TargetPlatform.linux => 'Linux',
              TargetPlatform.fuchsia => 'Fuchsia',
            };
      String? optional(String value) => value.trim().isEmpty ? null : value.trim();
      final request = BugReportRequest(
        source: 'mobile',
        bugType: type,
        severity: severity,
        title: title.trim(),
        description: description.trim(),
        stepsToReproduce: optional(steps),
        expectedBehavior: optional(expected),
        actualBehavior: optional(actual),
        deviceInfo: {
          'os': platform,
          'model': kIsWeb ? 'Web Browser' : '$platform Device',
          'app_version': ?version,
        },
        appVersion: version,
        tags: {
          'ghar360',
          ...tags.split(RegExp(r'[\n,]')).map((tag) => tag.trim()).where((tag) => tag.isNotEmpty),
        }.toList(growable: false),
      );
      final result = await repository.submitBugReport(request);
      if (!current()) return null;
      state = const AsyncData(null);
      return result;
    } catch (error, stack) {
      if (current()) state = AsyncError(authFailure(error), stack);
      return null;
    }
  }
}
