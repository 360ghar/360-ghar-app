// Typed offline-queue payloads. Serialized to maps for GetStorage; prefer
// constructing via constructors rather than hand-rolled maps at call sites.

sealed class OfflineAction {
  const OfflineAction({required this.timestamp, this.retries = 0});

  final DateTime timestamp;
  final int retries;

  String get type;
  OfflineAction copyWithRetries(int retries);
  Map<String, dynamic> toJson();

  static OfflineAction? tryParse(Map<String, dynamic> json) {
    final type = json['type']?.toString();
    final tsRaw = json['ts']?.toString();
    if (tsRaw == null || tsRaw.isEmpty) return null;
    final ts = DateTime.tryParse(tsRaw);
    if (ts == null) return null;
    final retries = (json['retries'] as num?)?.toInt() ?? 0;

    switch (type) {
      case OfflineSwipeAction.typeName:
        final propertyId = _parsePropertyId(json['propertyId']);
        if (propertyId == null) return null;
        final isLiked = json['isLiked'] == true || json['isLiked']?.toString() == 'true';
        return OfflineSwipeAction(
          propertyId: propertyId,
          isLiked: isLiked,
          timestamp: ts,
          retries: retries,
        );
      case OfflineVisitAction.typeName:
        final propertyId = _parsePropertyId(json['propertyId']);
        final scheduledDate = json['scheduledDate']?.toString();
        if (propertyId == null || scheduledDate == null || scheduledDate.isEmpty) {
          return null;
        }
        final special = json['specialRequirements']?.toString();
        return OfflineVisitAction(
          propertyId: propertyId,
          scheduledDate: scheduledDate,
          specialRequirements: (special == null || special.isEmpty) ? null : special,
          timestamp: ts,
          retries: retries,
        );
      default:
        return null;
    }
  }

  static int? _parsePropertyId(Object? raw) {
    if (raw is int) return raw;
    if (raw != null) return int.tryParse(raw.toString());
    return null;
  }
}

final class OfflineSwipeAction extends OfflineAction {
  static const typeName = 'swipe';

  const OfflineSwipeAction({
    required this.propertyId,
    required this.isLiked,
    required super.timestamp,
    super.retries,
  });

  final int propertyId;
  final bool isLiked;

  @override
  String get type => typeName;

  @override
  OfflineSwipeAction copyWithRetries(int retries) => OfflineSwipeAction(
    propertyId: propertyId,
    isLiked: isLiked,
    timestamp: timestamp,
    retries: retries,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': typeName,
    'propertyId': propertyId,
    'isLiked': isLiked,
    'ts': timestamp.toIso8601String(),
    'retries': retries,
  };
}

final class OfflineVisitAction extends OfflineAction {
  static const typeName = 'visit';

  const OfflineVisitAction({
    required this.propertyId,
    required this.scheduledDate,
    required super.timestamp,
    this.specialRequirements,
    super.retries,
  });

  final int propertyId;
  final String scheduledDate;
  final String? specialRequirements;

  @override
  String get type => typeName;

  @override
  OfflineVisitAction copyWithRetries(int retries) => OfflineVisitAction(
    propertyId: propertyId,
    scheduledDate: scheduledDate,
    specialRequirements: specialRequirements,
    timestamp: timestamp,
    retries: retries,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': typeName,
    'propertyId': propertyId,
    'scheduledDate': scheduledDate,
    if (specialRequirements != null) 'specialRequirements': specialRequirements,
    'ts': timestamp.toIso8601String(),
    'retries': retries,
  };
}
