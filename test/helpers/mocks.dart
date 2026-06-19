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

import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/data/models/agent_model.dart';
import 'package:ghar360/core/data/models/property_image_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:ghar360/features/properties/data/datasources/properties_remote_datasource.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:ghar360/features/swipes/data/datasources/swipes_remote_datasource.dart';
import 'package:ghar360/features/swipes/data/swipes_repository.dart';
import 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// GetX lifecycle shim
// ---------------------------------------------------------------------------
// The repositories below extend [GetxService], which inherits the GetX lifecycle
// fields `onStart` and `onDelete` (final [InternalFinalCallback] instances set
// by the real constructor). mocktail's [Mock] does NOT invoke the real
// constructor, so those fields resolve to `null`, and `Get.put` then throws
// `type 'Null' is not a subtype of type 'InternalFinalCallback<void>'` when it
// calls `onStart()` during controller initialization.
//
// [GetxServiceMock] restores valid no-op callbacks for the lifecycle members by
// re-declaring them as instance fields initialized at construction, so the
// mocks register into the GetX container cleanly. Mocks for classes that do NOT
// extend GetxService (ApiClient, the remote datasources) extend [Mock] directly.
abstract class GetxServiceMock extends Mock {
  /// No-op lifecycle callback backing GetX's `onStart`. Wired with an identity
  /// callback so `onStart()` (invoked by `Get.put`) does not throw.
  final InternalFinalCallback<void> onStart = InternalFinalCallback<void>(callback: () {});

  /// No-op lifecycle callback backing GetX's `onDelete`.
  final InternalFinalCallback<void> onDelete = InternalFinalCallback<void>(callback: () {});
}

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
class MockAuthRepository extends GetxServiceMock implements AuthRepository {}

// ---------------------------------------------------------------------------
// ProfileRepository
// ---------------------------------------------------------------------------

/// Mock for [ProfileRepository]. Covers: updateUserProfile, updateUserLocation,
/// updateUserPreferences, getCurrentUserProfile, calculateProfileCompletion,
/// isProfileComplete, updateProfileField, updateProfileImage.
class MockProfileRepository extends GetxServiceMock implements ProfileRepository {}

// ---------------------------------------------------------------------------
// PropertiesRepository
// ---------------------------------------------------------------------------

/// Mock for [PropertiesRepository]. Covers: getProperties, getPropertyDetail,
/// getPropertiesByIds, searchProperties, createProperty, updateProperty,
/// updatePropertyMedia, clearCache.
class MockPropertiesRepository extends GetxServiceMock implements PropertiesRepository {}

// ---------------------------------------------------------------------------
// SwipesRepository
// ---------------------------------------------------------------------------

/// Mock for [SwipesRepository]. Covers: recordSwipe, getSwipeHistoryProperties,
/// getLikedProperties, getPassedProperties, getLikedPropertiesWithSwipeIds,
/// getAllSwipedProperties.
class MockSwipesRepository extends GetxServiceMock implements SwipesRepository {}

// ---------------------------------------------------------------------------
// Core controllers (GetxController-based)
// ---------------------------------------------------------------------------
// LocationController and AuthController extend GetxController, which carries the
// same `onStart`/`onDelete` InternalFinalCallback lifecycle fields as
// GetxService, so they reuse [GetxServiceMock]'s no-op callback shim.

/// Mock for [LocationController]. Used where collaborators only hold a typed
/// reference and never drive its behavior (stub methods as needed per test).
class MockLocationController extends GetxServiceMock implements LocationController {}

/// Mock for [AuthController]. Used where collaborators only hold a typed
/// reference and never drive its behavior (stub methods as needed per test).
class MockAuthController extends GetxServiceMock implements AuthController {}

// ---------------------------------------------------------------------------
// Remote datasources
// ---------------------------------------------------------------------------

/// Mock for [PropertiesRemoteDatasource]. Covers: fetchProperties,
/// fetchPropertyById, fetchPropertiesByIds, searchProperties.
class MockPropertiesRemoteDatasource extends Mock implements PropertiesRemoteDatasource {}

/// Mock for [VisitsRemoteDatasource]. Covers: fetchVisitsSummary, scheduleVisit,
/// cancelVisit, rescheduleVisit, fetchRelationshipManager.
class MockVisitsRemoteDatasource extends Mock implements VisitsRemoteDatasource {}

/// Mock for [SwipesRemoteDatasource]. Covers: logSwipe, swipeProperty.
class MockSwipesRemoteDatasource extends Mock implements SwipesRemoteDatasource {}

/// Mock for [NotificationsRemoteDatasource]. Plain class (not a GetxService)
/// constructed with an [ApiClient]. Required because [AuthController]'s field
/// initializers `Get.find` it at construction time.
class MockNotificationsRemoteDatasource extends Mock implements NotificationsRemoteDatasource {}

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
  Map<String, dynamic>? preferences,
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
    filtersApplied: const <String, dynamic>{},
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
