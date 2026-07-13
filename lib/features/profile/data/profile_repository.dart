import 'package:get/get.dart';

import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/response_parser.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

/// Repository for managing user profile operations
/// Handles all profile-related API calls and data management
class ProfileRepository extends GetxService {
  ProfileRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? Get.find<ApiClient>();

  final ApiClient _apiClient;

  /// Updates the user profile on the backend
  Future<UserModel> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      DebugLogger.info('👤 Updating user profile with data: ${profileData.keys.join(', ')}');
      final response = await _apiClient.put(ApiPaths.usersProfile, body: profileData);
      final updatedUser = _parseUser(response.body);
      DebugLogger.success('✅ Profile updated successfully');
      return updatedUser;
    } on AppException catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to update user profile: ${e.message}', e, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      DebugLogger.error('Unexpected error updating user profile: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Updates the user's location on the backend (fire-and-forget, no profile refetch)
  Future<void> updateUserLocation(Map<String, dynamic> locationData) async {
    try {
      DebugLogger.info('📍 Updating user location');
      final lat = locationData['current_latitude'] as double?;
      final lon = locationData['current_longitude'] as double?;
      if (lat != null && lon != null) {
        await _apiClient.put(ApiPaths.usersLocation, body: {'latitude': lat, 'longitude': lon});
        DebugLogger.success('✅ Location updated successfully');
      }
    } on AppException catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to update user location: ${e.message}', e, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      DebugLogger.error('Unexpected error updating user location: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Updates the user's preferences on the backend
  Future<UserModel> updateUserPreferences(Map<String, dynamic> preferences) async {
    try {
      DebugLogger.info('⚙️ Updating user preferences');
      await _apiClient.put(ApiPaths.usersPreferences, body: preferences);
      // Refetch profile to get the most up-to-date user model
      return await getCurrentUserProfile();
    } on AppException catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to update user preferences: ${e.message}', e, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      DebugLogger.error('Unexpected error updating user preferences: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Gets the current user profile from the backend
  Future<UserModel> getCurrentUserProfile() async {
    try {
      DebugLogger.info('👤 Fetching current user profile');
      final response = await _apiClient.get(ApiPaths.usersProfile, useCache: false, dedupe: false);
      final user = _parseUser(response.body);
      DebugLogger.success('✅ User profile fetched successfully');
      return user;
    } on AppException catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to fetch user profile: ${e.message}', e, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      DebugLogger.error('Unexpected error fetching user profile: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Checks if the user profile is complete based on required fields
  bool isProfileComplete(UserModel user) {
    return user.isProfileComplete;
  }

  /// Updates a specific profile field
  Future<UserModel> updateProfileField(String field, dynamic value) async {
    return await updateUserProfile({field: value});
  }

  /// Uploads and updates user profile image
  /// Uploads a local image file as the user's avatar and returns the updated
  /// user. The backend `/users/me/avatar` endpoint stores the file (converting
  /// to WebP) and returns the user with the new `profile_image_url`.
  Future<UserModel> updateProfileImage(String imagePath) async {
    try {
      DebugLogger.info('📸 Uploading user profile image');
      final response = await _apiClient.upload(
        ApiPaths.usersAvatar,
        field: 'file',
        filePath: imagePath,
      );
      final updatedUser = _parseUser(response.body);
      DebugLogger.success('✅ Profile image uploaded successfully');
      return updatedUser;
    } on AppException catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to upload profile image: ${e.message}', e, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      DebugLogger.error('Unexpected error uploading profile image: $e', e, stackTrace);
      rethrow;
    }
  }

  UserModel _parseUser(dynamic raw) {
    final payload = ResponseParser.unwrapObject(raw);
    if (payload.isEmpty) {
      throw const FormatException('Unexpected user response payload');
    }

    payload['phone'] ??= '';
    if (payload['preferences'] is! Map<String, dynamic>) {
      payload['preferences'] = <String, dynamic>{};
    }

    return UserModel.fromJson(payload);
  }
}
