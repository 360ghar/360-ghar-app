import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/providers/app_database_provider.dart';

@immutable
class OnboardingState {
  const OnboardingState({
    required this.completed,
    this.locationExplained = false,
    this.save = const AsyncData(null),
  });
  final bool completed;

  /// Whether this device has shown the location explainer before the OS
  /// permission prompt.
  final bool locationExplained;
  final AsyncValue<void> save;
}

final onboardingProvider = NotifierProvider<OnboardingController, OnboardingState>(
  OnboardingController.new,
);

/// The widget owns its page and animation controllers. This provider owns only
/// the durable onboarding preferences; failed writes keep onboarding available.
class OnboardingController extends Notifier<OnboardingState> {
  static const _explainedKey = 'location_explainer_seen';

  @override
  OnboardingState build() {
    final database = ref.watch(appDatabaseProvider);
    return OnboardingState(
      completed: database.readPreference<bool>('has_seen_onboarding') ?? false,
      locationExplained: database.readPreference<bool>(_explainedKey) ?? false,
    );
  }

  Future<bool> complete() async {
    if (state.save.isLoading) return false;
    if (state.completed) return true;
    state = OnboardingState(
      completed: false,
      locationExplained: state.locationExplained,
      save: const AsyncLoading(),
    );
    try {
      await ref.read(appDatabaseProvider).writePreference('has_seen_onboarding', true);
      if (!ref.mounted) return false;
      state = OnboardingState(completed: true, locationExplained: state.locationExplained);
      return true;
    } catch (error, stack) {
      if (ref.mounted) {
        state = OnboardingState(
          completed: false,
          locationExplained: state.locationExplained,
          save: AsyncError(error, stack),
        );
      }
      return false;
    }
  }

  /// Records that the explainer was shown, whatever the user chose. A failed
  /// write only means the explainer may show once more.
  Future<void> markLocationExplained() async {
    if (state.locationExplained) return;
    state = OnboardingState(completed: state.completed, locationExplained: true, save: state.save);
    try {
      await ref.read(appDatabaseProvider).writePreference(_explainedKey, true);
    } on Object {
      // The in-memory flag still stops a repeat in this session.
    }
  }
}
