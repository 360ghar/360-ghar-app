import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/response_parser.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

/// The keys `PUT /users/profile` (`UserUpdate`) accepts from this app. The body is strict, so a
/// key outside this set is a 422. `email` and `profile_image_url` are not in it: an email changes
/// through Supabase and the avatar through its upload route. `preferences` has its own route.
const userUpdateKeys = {'full_name', 'phone', 'date_of_birth'};

/// The keys `PUT /users/preferences` (`UserPreferencesPatch`) accepts. A key sent as null is
/// removed; a key not sent keeps its value.
const userPreferencesKeys = {
  'property_type',
  'purpose',
  'budget_min',
  'budget_max',
  'bedrooms_min',
  'bedrooms_max',
  'area_min',
  'area_max',
  'location_preference',
  'max_distance_km',
};

/// Repository for managing user profile operations
/// Handles all profile-related API calls and data management
class ProfileRepository {
  ProfileRepository({required this._apiClient});

  final ApiClient _apiClient;

  /// Updates the user profile (`PUT /users/profile`) and returns the saved `SelfUser`. Only the
  /// keys in [userUpdateKeys] are sent; `null` clears a nullable key (a blank `date_of_birth`).
  Future<UserModel> updateUserProfile(Map<String, dynamic> profileData) async {
    _requireKeys(profileData, userUpdateKeys, 'profile');
    try {
      DebugLogger.info('👤 Updating user profile with data: ${profileData.keys.join(', ')}');
      final response = await _apiClient.put(ApiPaths.usersProfile, body: profileData);
      final updatedUser = _parseUser(response.body);
      DebugLogger.success('✅ Profile updated successfully');
      return updatedUser;
    } on AppException catch (e, stackTrace) {
      DebugLogger.error('Profile request failed', e.runtimeType, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      DebugLogger.error('Profile request failed', e.runtimeType, stackTrace);
      rethrow;
    }
  }

  /// Sends the device position (`PUT /users/location`, `LocationUpdate`: both keys, in range).
  /// The backend answers with `UserLocation`; nothing here reads it.
  Future<void> updateUserLocation({required double latitude, required double longitude}) async {
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) return;
    try {
      DebugLogger.info('📍 Updating user location');
      await _apiClient.put(
        ApiPaths.usersLocation,
        body: {'latitude': latitude, 'longitude': longitude},
      );
      DebugLogger.success('✅ Location updated successfully');
    } on AppException catch (e, stackTrace) {
      DebugLogger.error('Profile request failed', e.runtimeType, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      DebugLogger.error('Profile request failed', e.runtimeType, stackTrace);
      rethrow;
    }
  }

  /// Merges [patch] into the stored preferences (`PUT /users/preferences`) and returns the
  /// preferences the backend now holds. This is the only writer of preferences.
  Future<UserPreferences> updateUserPreferences(Map<String, dynamic> patch) async {
    _requireKeys(patch, userPreferencesKeys, 'preferences');
    try {
      DebugLogger.info('⚙️ Updating user preferences');
      final response = await _apiClient.put(ApiPaths.usersPreferences, body: patch);
      return UserPreferences.fromJson(ResponseParser.object(response.body));
    } on AppException catch (e, stackTrace) {
      DebugLogger.error('Profile request failed', e.runtimeType, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      DebugLogger.error('Profile request failed', e.runtimeType, stackTrace);
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
      DebugLogger.error('Profile request failed', e.runtimeType, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      DebugLogger.error('Profile request failed', e.runtimeType, stackTrace);
      rethrow;
    }
  }

  /// Checks if the user profile is complete based on required fields
  bool isProfileComplete(UserModel user) {
    return user.isProfileComplete;
  }

  /// Uploads a local image file as the user's avatar and returns the updated user. The backend
  /// `/users/me/avatar` endpoint stores the file (converting to WebP) and returns the `SelfUser`
  /// with the new `profile_image_url`.
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
      DebugLogger.error('Profile request failed', e.runtimeType, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      DebugLogger.error('Profile request failed', e.runtimeType, stackTrace);
      rethrow;
    }
  }

  /// A `SelfUser`. A body that does not have the contract shape is a malformed response.
  UserModel _parseUser(dynamic raw) {
    try {
      return UserModel.fromJson(ResponseParser.object(raw));
    } catch (error, stack) {
      DebugLogger.error('User response rejected', error.runtimeType, stack);
      throw ServerException(
        'The service returned an invalid profile response.',
        code: 'MALFORMED_RESPONSE',
      );
    }
  }

  /// The backend rejects an undeclared key with a 422, so a caller bug fails here, before a
  /// request is made.
  static void _requireKeys(Map<String, dynamic> body, Set<String> allowed, String what) {
    final unknown = body.keys.where((key) => !allowed.contains(key));
    if (unknown.isNotEmpty) {
      throw ArgumentError('Undeclared $what keys: ${unknown.join(', ')}');
    }
  }
}
