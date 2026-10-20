enum ChatRole { user, assistant, toolCall, toolResult, error, widget }

class ChatMessageModel {
  final String id;
  final ChatRole role;
  final String content;
  final String? toolName;
  final Map<String, dynamic>? toolArgs;
  final Map<String, dynamic>? toolResult;
  final String? widgetName;
  final Map<String, dynamic>? widgetData;
  final DateTime timestamp;
  final bool isStreaming;

  const ChatMessageModel({
    required this.id,
    required this.role,
    required this.content,
    this.toolName,
    this.toolArgs,
    this.toolResult,
    this.widgetName,
    this.widgetData,
    required this.timestamp,
    this.isStreaming = false,
  });

  ChatMessageModel copyWith({
    String? content,
    bool? isStreaming,
    Map<String, dynamic>? toolResult,
    String? widgetName,
    Map<String, dynamic>? widgetData,
  }) {
    return ChatMessageModel(
      id: id,
      role: role,
      content: content ?? this.content,
      toolName: toolName,
      toolArgs: toolArgs,
      toolResult: toolResult ?? this.toolResult,
      widgetName: widgetName ?? this.widgetName,
      widgetData: widgetData ?? this.widgetData,
      timestamp: timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  /// A stored message (`ConversationMessageOut`): `id`, `role` and `created_at` always come;
  /// `role` is `user`, `assistant` or `widget`. A widget row carries `widget_name` and
  /// `widget_data`. Anything else is a contract break and throws a [FormatException].
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final createdAt = json['created_at'];
    if (id is! int || createdAt is! String) {
      throw const FormatException('Message needs an integer id and a created_at string');
    }
    final content = json['content'];
    if (content != null && content is! String) {
      throw const FormatException('Message content is not a string');
    }
    return ChatMessageModel(
      id: '$id',
      role: _parseRole(json['role']),
      content: content as String? ?? '',
      toolName: _asString(json['tool_name']),
      toolArgs: _asMap(json['tool_args']),
      toolResult: _asMap(json['tool_result']),
      widgetName: _asString(json['widget_name']),
      widgetData: _asMap(json['widget_data']),
      timestamp: DateTime.parse(createdAt),
    );
  }

  static String? _asString(dynamic value) {
    if (value == null || value is String) return value as String?;
    throw const FormatException('Message field is not a string');
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value == null) return null;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Message field is not an object');
  }

  static ChatRole _parseRole(Object? role) => switch (role) {
    'user' => ChatRole.user,
    'assistant' => ChatRole.assistant,
    'widget' => ChatRole.widget,
    _ => throw FormatException('Unknown message role: $role'),
  };
}
