import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/features/assistant/presentation/widgets/chat_input_bar.dart';
import '../../../../helpers/knife_finders.dart';
import '../../../../helpers/provider_test_app.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester, Widget child, {bool withTranslations = true}) async {
    await tester.pumpProviderApp(Scaffold(body: Center(child: child)));
  }

  testWidgets('renders text field with hint text', (tester) async {
    await pumpBar(tester, ChatInputBar(onSend: (_) {}));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Ask me anything...'), findsOneWidget);
  });

  testWidgets('renders send button with arrow icon when not streaming', (tester) async {
    await pumpBar(tester, ChatInputBar(onSend: (_) {}));

    expect(findKnife(KnifeIcon.arrowUpRight), findsOneWidget);
    expect(findKnife(KnifeIcon.stop), findsNothing);
  });

  testWidgets('renders stop button when streaming', (tester) async {
    await pumpBar(tester, ChatInputBar(onSend: (_) {}, isStreaming: true, onCancel: () {}));

    expect(findKnife(KnifeIcon.stop), findsOneWidget);
    expect(findKnife(KnifeIcon.arrowUpRight), findsNothing);
  });

  testWidgets('calls onSend with trimmed text when send button tapped', (tester) async {
    String? sentText;
    await pumpBar(tester, ChatInputBar(onSend: (text) => sentText = text));

    await tester.enterText(find.byType(TextField), '  Hello world  ');
    await tester.pump();

    await tester.tap(findKnife(KnifeIcon.arrowUpRight));
    await tester.pump();

    expect(sentText, 'Hello world');
  });

  testWidgets('clears text field after sending', (tester) async {
    await pumpBar(tester, ChatInputBar(onSend: (_) {}));

    await tester.enterText(find.byType(TextField), 'Test message');
    await tester.pump();

    await tester.tap(findKnife(KnifeIcon.arrowUpRight));
    await tester.pump();

    expect(find.text('Test message'), findsNothing);
  });

  testWidgets('does not send when text is empty', (tester) async {
    var sendCount = 0;
    await pumpBar(tester, ChatInputBar(onSend: (_) => sendCount++));

    await tester.tap(findKnife(KnifeIcon.arrowUpRight));
    await tester.pump();

    expect(sendCount, 0);
  });

  testWidgets('does not send when text is only whitespace', (tester) async {
    var sendCount = 0;
    await pumpBar(tester, ChatInputBar(onSend: (_) => sendCount++));

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    await tester.tap(findKnife(KnifeIcon.arrowUpRight));
    await tester.pump();

    expect(sendCount, 0);
  });

  testWidgets('does not send when streaming', (tester) async {
    var sendCount = 0;
    await pumpBar(tester, ChatInputBar(onSend: (_) => sendCount++, isStreaming: true));

    // When streaming, the send button is replaced by stop button.
    // There is no send button to tap.
    expect(findKnife(KnifeIcon.arrowUpRight), findsNothing);
    expect(sendCount, 0);
  });

  testWidgets('calls onCancel when stop button tapped', (tester) async {
    var cancelCount = 0;
    await pumpBar(
      tester,
      ChatInputBar(onSend: (_) {}, isStreaming: true, onCancel: () => cancelCount++),
    );

    await tester.tap(findKnife(KnifeIcon.stop));
    await tester.pump();

    expect(cancelCount, 1);
  });

  testWidgets('send button is disabled when no text', (tester) async {
    await pumpBar(tester, ChatInputBar(onSend: (_) {}));

    // The GestureDetector wrapping the send button should have null onTap
    // when there is no text.
    final gestureDetector = tester.widget<GestureDetector>(
      find.ancestor(of: findKnife(KnifeIcon.arrowUpRight), matching: find.byType(GestureDetector)),
    );
    expect(gestureDetector.onTap, isNull);
  });

  testWidgets('send button is enabled when text is present', (tester) async {
    await pumpBar(tester, ChatInputBar(onSend: (_) {}));

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();

    final gestureDetector = tester.widget<GestureDetector>(
      find.ancestor(of: findKnife(KnifeIcon.arrowUpRight), matching: find.byType(GestureDetector)),
    );
    expect(gestureDetector.onTap, isNotNull);
  });
}
