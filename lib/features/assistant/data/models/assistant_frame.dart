import 'package:ghar360/core/data/models/wire_enums.dart';
import 'package:ghar360/core/network/sse_client.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

export 'package:ghar360/core/data/models/wire_enums.dart' show AssistantErrorCode;

/// One frame of the assistant stream (`POST /agent/chat`, `AgentStreamEvent`): `conversation_info`,
/// `text_chunk`, `tool_call_start`, `tool_call_end`, `widget`, `done` and `error`.
///
/// [fromEvent] reads the frame strictly: a key the backend always sends must be there with its
/// type, or the read throws a [FormatException] and the stream fails. A frame name this app does
/// not know is not an error of the reply: it reads as null and is logged.
sealed class AssistantFrame {
  const AssistantFrame();

  static AssistantFrame? fromEvent(SseEvent event) {
    final data = event.data;
    switch (event.event) {
      case 'conversation_info':
        return ConversationInfoFrame(_int(data, 'conversation_id'));
      case 'text_chunk':
        return TextChunkFrame(_string(data, 'text'));
      case 'tool_call_start':
        return ToolCallStartFrame(callId: _string(data, 'call_id'), tool: _string(data, 'tool'));
      case 'tool_call_end':
        return ToolCallEndFrame(
          callId: _string(data, 'call_id'),
          tool: _string(data, 'tool'),
          success: _bool(data, 'success'),
        );
      case 'widget':
        // `data` is `{widget_name, structured_content}`; the SSE payload is that object.
        final content = data['structured_content'];
        if (content != null && content is! Map) {
          throw const FormatException('widget: structured_content is not an object');
        }
        return WidgetFrame(
          widgetName: _string(data, 'widget_name'),
          structuredContent: content == null ? null : Map<String, dynamic>.from(content as Map),
        );
      case 'done':
        return DoneFrame(_string(data, 'response_text'));
      case 'error':
        return ErrorFrame(
          code: AssistantErrorCode.fromJson(data['code']),
          message: _string(data, 'message'),
        );
    }
    DebugLogger.warning('Unknown assistant frame ignored', event.event);
    return null;
  }

  static String _string(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String) return value;
    throw FormatException('Assistant frame: $key is not a string');
  }

  static int _int(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is int) return value;
    throw FormatException('Assistant frame: $key is not an integer');
  }

  static bool _bool(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is bool) return value;
    throw FormatException('Assistant frame: $key is not a boolean');
  }
}

/// The conversation this reply belongs to. It is new when the request named none.
final class ConversationInfoFrame extends AssistantFrame {
  const ConversationInfoFrame(this.conversationId);
  final int conversationId;
}

/// A piece of the reply text.
final class TextChunkFrame extends AssistantFrame {
  const TextChunkFrame(this.text);
  final String text;
}

/// A tool started. Two calls of one step run at once, so [callId] tells them apart.
final class ToolCallStartFrame extends AssistantFrame {
  const ToolCallStartFrame({required this.callId, required this.tool});
  final String callId;
  final String tool;
}

/// A tool ended. [success] is false when its result carried an error.
final class ToolCallEndFrame extends AssistantFrame {
  const ToolCallEndFrame({required this.callId, required this.tool, required this.success});
  final String callId;
  final String tool;
  final bool success;
}

/// A tool result the reply shows as a widget. [structuredContent] is the typed payload of
/// [widgetName]; it is null when the tool gave none.
final class WidgetFrame extends AssistantFrame {
  const WidgetFrame({required this.widgetName, this.structuredContent});
  final String widgetName;
  final Map<String, dynamic>? structuredContent;
}

/// The reply is complete and saved. [responseText] is the whole text.
final class DoneFrame extends AssistantFrame {
  const DoneFrame(this.responseText);
  final String responseText;
}

/// The reply failed. [message] is fixed server text; the app shows its own localized text for
/// [code], which is null for a code this app does not know.
final class ErrorFrame extends AssistantFrame {
  const ErrorFrame({required this.code, required this.message});
  final AssistantErrorCode? code;
  final String message;
}
