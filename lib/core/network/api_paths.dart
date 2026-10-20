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
  static String visitCancel(int visitId) => '/visits/$visitId/cancel';
  static String visitReschedule(int visitId) => '/visits/$visitId/reschedule';

  // Agents
  static const String agentsAssigned = '/agents/assigned';

  // Auth
  static const String identifierStatus = '/auth/identifier-status';
  static const String lastMethod = '/auth/last-method';

  // Users/Profile
  static const String usersMe = '/users/me';
  static const String usersProfile = '/users/profile';
  static const String usersLocation = '/users/location';
  static const String usersPreferences = '/users/preferences';
  static const String usersAvatar = '/users/me/avatar';
  static const String usersNotificationSettings = '/users/notification-settings';

  // Amenities
  static const String amenities = '/amenities';

  // Agent (Assistant)
  static const String agentChat = '/agent/chat';
  static const String agentConversations = '/agent/conversations';
  static String agentConversation(int id) => '$agentConversations/$id';

  /// The only messages route: a `CursorPage`. The bare `/messages` list is removed (404).
  static String agentMessagesPage(int id) => '${agentConversation(id)}/messages/page';
  static String agentWidget(String name) => '/agent/widgets/${Uri.encodeComponent(name)}';

  // Swipes
  static const String swipes = '/swipes';

  // Notifications
  static const String notificationsDeviceRegister = '/notifications/devices/register';
  static const String notificationsDeviceUnregister = '/notifications/devices/unregister';

  // Support
  static const String bugs = '/bugs';

  // App updates (public)
  static const String versionsCheck = '/versions/check';

  // Static Pages
  static String staticPagePublic(String uniqueName) => '/pages/$uniqueName/public';
}
