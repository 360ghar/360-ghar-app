/// Persisted preference names and keys recognized by the legacy importer.
///
/// Keep persisted string values stable so installed data remains readable.
/// The database and read-only importer define which keys are currently used.
/// Keys are grouped by domain.
abstract final class StorageKeys {
  // ---------------------------------------------------------------------------
  // Filters (shared purpose and property type preferences)
  // ---------------------------------------------------------------------------
  static const String globalPurpose = 'global_purpose';
  static const String globalPropertyTypes = 'global_property_types';

  // ---------------------------------------------------------------------------
  // Legacy page snapshots and schema version
  // ---------------------------------------------------------------------------
  static const String exploreState = 'explore_state';
  static const String discoverState = 'discover_state';
  static const String likesState = 'likes_state';
  static const String pageStateSchemaVersion = 'page_state_schema_version';

  // ---------------------------------------------------------------------------
  // Theme and locale preferences
  // ---------------------------------------------------------------------------
  static const String themeMode = 'themeMode';
  static const String languageCode = 'language_code';
  static const String countryCode = 'country_code';

  // ---------------------------------------------------------------------------
  // Onboarding preference
  // ---------------------------------------------------------------------------
  static const String hasSeenOnboarding = 'has_seen_onboarding';

  // ---------------------------------------------------------------------------
  // Auth (LastAuthMethodStore)
  // ---------------------------------------------------------------------------
  static const String lastAuthMethod = 'last_auth_method';
  static const String lastAuthIdentifierHint = 'last_auth_identifier_hint';
  static const String lastAuthMethodAt = 'last_auth_method_at';

  // ---------------------------------------------------------------------------
  // App update (AppUpdateController)
  // ---------------------------------------------------------------------------
  static const String skippedAppVersion = 'skipped_app_version';

  // ---------------------------------------------------------------------------
  // Preferences (PreferencesController notification toggles)
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Tools (DocumentChecklistController)
  // ---------------------------------------------------------------------------
  static const String documentChecklist = 'document_checklist';

  // ---------------------------------------------------------------------------
  // Legacy ETag cache prefix
  // ---------------------------------------------------------------------------
  static const String etagCachePrefix = 'etag_cache_';

  // ---------------------------------------------------------------------------
  // Firebase consent gating (FirebaseInitializer)
  // ---------------------------------------------------------------------------
  static const String consentAnalytics = 'consent_analytics';
  static const String consentPerformance = 'consent_performance';
}
