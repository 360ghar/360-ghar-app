import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/auth/data/auth_failure.dart';

@immutable
class EditProfileState {
  const EditProfileState({this.saving = false, this.uploading = false, this.error});
  final bool saving;
  final bool uploading;
  final AppException? error;
  bool get busy => saving || uploading;
}

final editProfileProvider = NotifierProvider.autoDispose<EditProfileController, EditProfileState>(
  EditProfileController.new,
);

class EditProfileController extends Notifier<EditProfileState> {
  int _generation = 0;
  @override
  EditProfileState build() {
    ref.watch(authProvider.select((value) => value.user?.supabaseUserId));
    _generation++;
    ref.onDispose(() {
      _generation++;
    });
    return const EditProfileState();
  }

  Future<bool> saveProfile({
    required String name,
    required String location,
    DateTime? dateOfBirth,
  }) async {
    final user = ref.read(authProvider).user;
    if (state.busy || user == null) return false;
    final session = ref.read(authProvider.notifier);
    final generation = _generation;
    state = const EditProfileState(saving: true);
    try {
      // The place lives in preferences, which have their own writer: a key sent as null is
      // removed. The profile save carries only the keys of `UserUpdate`.
      final place = location.trim();
      if (place != (user.preferences.location ?? '')) {
        final placeSaved = await session.updateUserPreferences({
          'location_preference': place.isEmpty ? null : [place],
        });
        if (!ref.mounted || generation != _generation) return false;
        if (!placeSaved) {
          state = EditProfileState(error: ref.read(authProvider).mutation.error as AppException?);
          return false;
        }
      }
      final saved = await session.updateUserProfile({
        'full_name': name.trim(),
        'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      });
      if (!ref.mounted || generation != _generation) return false;
      state = EditProfileState(
        error: saved ? null : ref.read(authProvider).mutation.error as AppException?,
      );
      return saved;
    } catch (error) {
      if (ref.mounted && generation == _generation) {
        state = EditProfileState(error: authFailure(error));
      }
      return false;
    }
  }

  Future<bool> uploadImage(String path) async {
    if (state.busy) return false;
    final session = ref.read(authProvider.notifier);
    final generation = _generation;
    state = const EditProfileState(uploading: true);
    try {
      final saved = await session.updateProfileImage(path);
      if (!ref.mounted || generation != _generation) return false;
      state = EditProfileState(
        error: saved ? null : ref.read(authProvider).mutation.error as AppException?,
      );
      return saved;
    } catch (error) {
      if (ref.mounted && generation == _generation) {
        state = EditProfileState(error: authFailure(error));
      }
      return false;
    }
  }
}
