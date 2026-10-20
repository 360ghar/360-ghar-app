/// `AIConversationSummary`: one conversation in the history list.
class ConversationModel {
  final int id;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;

  const ConversationModel({
    required this.id,
    this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messageCount = 0,
  });

  /// `id`, `created_at` and `updated_at` always come, `title` can be null and `message_count`
  /// defaults to 0. Anything else is a contract break and throws a [FormatException]: a
  /// conversation with no id or no date has no place in a list sorted by latest.
  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final createdAt = json['created_at'];
    final updatedAt = json['updated_at'];
    final title = json['title'];
    final count = json['message_count'];
    if (id is! int ||
        createdAt is! String ||
        updatedAt is! String ||
        (title != null && title is! String) ||
        (count != null && count is! int)) {
      throw const FormatException('Conversation summary does not match the contract');
    }
    return ConversationModel(
      id: id,
      title: title as String?,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
      messageCount: count as int? ?? 0,
    );
  }

  /// The server shape, for the SQLite first-page cache.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'message_count': messageCount,
  };
}
