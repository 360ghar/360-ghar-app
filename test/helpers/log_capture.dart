import 'package:logger/logger.dart';

/// Captures exactly the diagnostics sent to the logger's output boundary.
class LogCapture {
  LogCapture() {
    Logger.addOutputListener(_capture);
  }
  final List<OutputEvent> events = [];
  String get text => events.expand((event) => event.lines).join('\n');
  void _capture(OutputEvent event) => events.add(event);
  void close() => Logger.removeOutputListener(_capture);
}
