class ApiPaths {
  const ApiPaths._();

  static const String apiVersionPrefix = '/api/v1';

  static String normalize(String endpoint) {
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      return endpoint;
    }

    var normalized = endpoint.trim();
    if (normalized.isEmpty) {
      return apiVersionPrefix;
    }

    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }

    if (normalized.startsWith(apiVersionPrefix)) {
      return normalized;
    }

    return '$apiVersionPrefix$normalized';
  }

  // Properties
  static const String properties = '/properties';
  static String propertyById(String propertyId) => '/properties/$propertyId';

  // Visits
  static const String visits = '/visits';
  static String visitById(int visitId) => '/visits/$visitId';
  static const String visitsUpcoming = '/visits/upcoming';
  static const String visitsPast = '/visits/past';
  static String visitCancel(int visitId) => '/visits/$visitId/cancel';
  static String visitReschedule(int visitId) => '/visits/$visitId/reschedule';

  // Agents
  static const String agentsAssigned = '/agents/assigned';

  // Users/Profile
  static const String usersProfile = '/users/profile';
  static const String usersLocation = '/users/location';
  static const String usersPreferences = '/users/preferences';
  static const String usersMe = '/users/me';

  // Swipes
  static const String swipes = '/swipes';
  static const String swipesHistory = swipes;

  // Notifications
  static const String notificationsDeviceRegister = '/notifications/devices/register';
  static const String notificationsDeviceUnregister = '/notifications/devices/unregister';

  // Support
  static const String bugs = '/bugs';

  // Static Pages
  static String staticPagePublic(String uniqueName) => '/pages/$uniqueName/public';
}
