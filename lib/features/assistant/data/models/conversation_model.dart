class ConversationModel {
  final int? id;
  final String? title;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int messageCount;

  const ConversationModel({
    required this.id,
    this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    // Don't substitute 0 for a missing/garbled id — that puts a phantom
    // "conversation 0" into lists and breaks any client-side routing keyed
    // on the id. Surface null; callers that need an id must validate first.
    final int? id;
    final rawId = json['id'];
    if (rawId is int) {
      id = rawId;
    } else if (rawId is String) {
      id = int.tryParse(rawId);
    } else {
      id = null;
    }

    // Don't silently substitute DateTime(1970) for missing/malformed
    // timestamps — that put genuinely recent conversations at the bottom
    // of a "sort by latest" list and rendered "Jan 1, 1970" in the UI.
    // Surface null and let the UI handle it (greyed-out / "Unknown" date).
    final createdAtStr = json['created_at'] as String?;
    final updatedAtStr = json['updated_at'] as String?;

    return ConversationModel(
      id: id,
      title: json['title']?.toString(),
      createdAt: createdAtStr != null ? DateTime.tryParse(createdAtStr) : null,
      updatedAt: updatedAtStr != null ? DateTime.tryParse(updatedAtStr) : null,
      messageCount: _parseMessageCount(json['message_count']),
    );
  }

  static int _parseMessageCount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
