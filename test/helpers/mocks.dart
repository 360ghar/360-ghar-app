// test/helpers/mocks.dart
//
// Mocktail [Mock] subclasses for the key dependency boundaries used across the
// app's controllers and repositories. Each mirror's a real production class's
// public surface so tests can stub return values with `when(...).thenAnswer`
// and verify interactions with `verify(...).called(...)`.
//
// Why mocktail (not mockito): no codegen required — the classes below are
// plain concrete-type mocks that compile on their own.
//
// NOTE: the underlying real classes are concrete (they do not implement shared
// interfaces), so callers must reference these mocks via the concrete type
// name (e.g. `MockProfileRepository`) rather than a shared abstraction.

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/models/agent_model.dart';
import 'package:ghar360/core/data/models/property_image_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/sse_client.dart';
import 'package:ghar360/core/services/google_places_service.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:ghar360/features/properties/data/datasources/properties_remote_datasource.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:ghar360/features/swipes/data/swipes_repository.dart';
import 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart';
import 'package:ghar360/features/visits/data/visits_repository.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// ApiClient
// ---------------------------------------------------------------------------

/// Mock for [ApiClient]. Covers: get, post, put, delete, patch, upload,
/// clearCache, baseUrl.
class MockApiClient extends Mock implements ApiClient {}

// ---------------------------------------------------------------------------
// AuthRepository (Supabase-backed auth surface)
// ---------------------------------------------------------------------------

/// Mock for [AuthRepository]. Covers: checkIdentifierStatus, recordLastMethod,
/// signInWithGoogle, signInWithApple, signUpWithPhonePassword,
/// signInWithPhonePassword, verifyPhoneOtp, sendPhoneOtp, signUpWithEmailOtp,
/// signInWithEmailPassword, sendEmailOtp, verifyEmailOtp, startAddPhone,
/// addAndVerifyPhone, updateUserPassword, signOut, waitForAccessToken,
/// currentUser, currentSession, onAuthStateChange, isGoogleSignInConfigured,
/// isAppleSignInSupported, isOAuthRedirectUri, completeOAuthFromUri,
/// lastAuthMethodStore.
class MockAuthRepository extends Mock implements AuthRepository {}

// ---------------------------------------------------------------------------
// ProfileRepository
// ---------------------------------------------------------------------------

/// Mock for [ProfileRepository]. Covers: updateUserProfile, updateUserLocation,
/// updateUserPreferences, getCurrentUserProfile, isProfileComplete,
/// updateProfileField, updateProfileImage.
class MockProfileRepository extends Mock implements ProfileRepository {}

// ---------------------------------------------------------------------------
// PropertiesRepository
// ---------------------------------------------------------------------------

/// Mock for [PropertiesRepository]. Covers: getProperties, getPropertyDetail,
/// searchProperties, clearCache.
class MockPropertiesRepository extends Mock implements PropertiesRepository {}

// ---------------------------------------------------------------------------
// SwipesRepository
// ---------------------------------------------------------------------------

/// Mock for [SwipesRepository]. Covers: recordSwipe, getSwipeHistoryProperties,
/// getLikedProperties, getPassedProperties, getLikedPropertiesWithSwipeIds,
/// getAllSwipedProperties.
class MockSwipesRepository extends Mock implements SwipesRepository {}

/// Typed mock for callers that do not require Riverpod state ownership.
class MockAuthController extends Mock implements AuthController {}

// ---------------------------------------------------------------------------
// Remote datasources
// ---------------------------------------------------------------------------

/// Mock for [PropertiesRemoteDatasource]. Covers: fetchProperties,
/// fetchPropertyById, searchProperties.
class MockPropertiesRemoteDatasource extends Mock implements PropertiesRemoteDatasource {}

/// Mock for [VisitsRemoteDatasource]. Covers: fetchVisitsSummary, scheduleVisit,
/// cancelVisit, rescheduleVisit, fetchRelationshipManager.
class MockVisitsRemoteDatasource extends Mock implements VisitsRemoteDatasource {}

/// Mock for [VisitsRepository]. Controllers depend on the repository, not the
/// remote datasource.
class MockVisitsRepository extends Mock implements VisitsRepository {}

/// Mock for the injected notification API.
class MockNotificationsRemoteDatasource extends Mock implements NotificationsRemoteDatasource {}

// ---------------------------------------------------------------------------
// Assistant
// ---------------------------------------------------------------------------

/// Mock for [AssistantRepository]. Covers: streamChat, getConversations,
/// getMessagesPage, getConversationMessages, getWidgetHtml, deleteConversation.
class MockAssistantRepository extends Mock implements AssistantRepository {}

/// Mock for [SseClient]. Covers: postStream.
class MockSseClient extends Mock implements SseClient {}

// ---------------------------------------------------------------------------
// Lightweight value factories used by tests to seed mock return values.
// Kept here so test authors do not have to re-derive model constructors.
// ---------------------------------------------------------------------------

/// Builds a [UserModel] with sensible test defaults. All fields overridable.
UserModel testUserModel({
  int id = 1,
  String supabaseUserId = 'supabase-123',
  String email = 'test@example.com',
  String? fullName,
  String? phone,
  bool isVerified = false,
  bool isActive = true,
  UserPreferences preferences = const UserPreferences(),
}) {
  return UserModel(
    id: id,
    supabaseUserId: supabaseUserId,
    email: email,
    fullName: fullName,
    phone: phone,
    isActive: isActive,
    isVerified: isVerified,
    preferences: preferences,
    createdAt: DateTime(2024, 1, 1),
  );
}

/// Builds an empty [UnifiedFilterModel] for repository calls that require one.
UnifiedFilterModel testFilterModel() => const UnifiedFilterModel();

/// Builds an empty [UnifiedPropertyResponse] (single page, no results).
UnifiedPropertyResponse testPropertyResponse({
  List<PropertyModel> items = const [],
  int limit = 20,
  String? nextCursor,
  bool hasMore = false,
}) {
  return UnifiedPropertyResponse(
    items: items,
    limit: limit,
    nextCursor: nextCursor,
    hasMore: hasMore,
  );
}

/// Builds a minimal [PropertyModel] for tests that need one.
PropertyModel testPropertyModel({int id = 100}) {
  return PropertyModel(
    id: id,
    title: 'Test Property $id',
    basePrice: 5000000,
    images: const <PropertyImageModel>[],
    isAvailable: true,
    viewCount: 0,
    likeCount: 0,
    interestCount: 0,
  );
}

/// Builds a minimal [VisitModel] for tests that need one.
VisitModel testVisitModel({int id = 1, int userId = 1}) {
  return VisitModel(
    id: id,
    propertyId: 100,
    userId: userId,
    scheduledDate: DateTime(2025, 1, 1, 10),
    status: VisitStatus.scheduled,
    createdAt: DateTime(2024, 1, 1),
  );
}

/// Builds a minimal [AgentModel] for tests that need one.
AgentModel testAgentModel({int id = 1}) {
  return AgentModel(
    id: id,
    name: 'Test Agent',
    agentType: AgentType.general,
    experienceLevel: ExperienceLevel.intermediate,
    createdAt: DateTime(2024, 1, 1),
  );
}

/// Mock for [GooglePlacesService]. Covers: getPlaceSuggestions, getPlaceDetails.
class MockGooglePlacesService extends Mock implements GooglePlacesService {}

/// Mock for the injected offline queue.
class MockOfflineQueueService extends Mock implements OfflineQueueService {}
