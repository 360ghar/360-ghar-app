import 'package:flutter/material.dart';

import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:ghar360/features/assistant/presentation/widgets/chat_message_bubble.dart';

ChatMessageModel _userMessage({String content = 'Hello there'}) {
  return ChatMessageModel(
    id: '1',
    role: ChatRole.user,
    content: content,
    timestamp: DateTime.now(),
  );
}

ChatMessageModel _assistantMessage({String content = 'Hi! How can I help?'}) {
  return ChatMessageModel(
    id: '2',
    role: ChatRole.assistant,
    content: content,
    timestamp: DateTime.now(),
  );
}

ChatMessageModel _streamingMessage({String content = ''}) {
  return ChatMessageModel(
    id: '3',
    role: ChatRole.assistant,
    content: content,
    timestamp: DateTime.now(),
    isStreaming: true,
  );
}

void main() {
  Future<void> pumpBubble(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: SingleChildScrollView(child: child)),
        ),
      ),
    );
  }

  testWidgets('renders user message content as SelectableText', (tester) async {
    await pumpBubble(tester, ChatMessageBubble(message: _userMessage()));

    expect(find.text('Hello there'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('renders assistant message content as MarkdownBody', (tester) async {
    await pumpBubble(tester, ChatMessageBubble(message: _assistantMessage()));

    expect(find.textContaining('How can I help'), findsOneWidget);
    expect(find.byType(MarkdownBody), findsOneWidget);
  });

  testWidgets('renders assistant markdown with bold text', (tester) async {
    final msg = _assistantMessage(content: 'This is **bold** text');
    await pumpBubble(tester, ChatMessageBubble(message: msg));

    // MarkdownBody is used to render the markdown content.
    expect(find.byType(MarkdownBody), findsOneWidget);
  });

  testWidgets('renders streaming message with content as SelectableText', (tester) async {
    final msg = _streamingMessage(content: 'Partial response');
    await pumpBubble(tester, ChatMessageBubble(message: msg));

    expect(find.text('Partial response'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    // MarkdownBody should NOT be used during streaming.
    expect(find.byType(MarkdownBody), findsNothing);
  });

  testWidgets('shows typing indicator when streaming with empty content', (tester) async {
    final msg = _streamingMessage(content: '');
    await pumpBubble(tester, ChatMessageBubble(message: msg));

    // Use pump (not pumpAndSettle) because the typing indicator has an
    // infinite animation.
    await tester.pump();

    // The typing indicator renders 3 small dot containers.
    final dots = tester.widgetList<Container>(
      find.ancestor(
        of: find.byWidgetPredicate(
          (w) => w is Container && (w.constraints?.maxWidth == 7 || false),
        ),
        matching: find.byType(Container),
      ),
    );
    // Verify the typing indicator is shown (3 dots in a Row).
    expect(find.byType(AnimatedBuilder), findsWidgets);
  });

  testWidgets('aligns user message to the right', (tester) async {
    await pumpBubble(tester, ChatMessageBubble(message: _userMessage()));

    final align = tester.widget<Align>(find.byType(Align));
    expect(align.alignment, Alignment.centerRight);
  });

  testWidgets('aligns assistant message to the left', (tester) async {
    await pumpBubble(tester, ChatMessageBubble(message: _assistantMessage()));

    final align = tester.widget<Align>(find.byType(Align));
    expect(align.alignment, Alignment.centerLeft);
  });

  testWidgets('applies different padding for user vs assistant', (tester) async {
    // User message: left padding 48, right padding 16
    await pumpBubble(tester, ChatMessageBubble(message: _userMessage()));
    final userPadding = tester.widgetList<Padding>(find.byType(Padding)).first.padding;
    expect(userPadding, isA<EdgeInsets>());
    final userEdges = userPadding as EdgeInsets;
    expect(userEdges.left, 48);
    expect(userEdges.right, 16);

    // Assistant message: left padding 16, right padding 48
    await pumpBubble(tester, ChatMessageBubble(message: _assistantMessage()));
    final assistantPadding = tester.widgetList<Padding>(find.byType(Padding)).first.padding;
    final assistantEdges = assistantPadding as EdgeInsets;
    expect(assistantEdges.left, 16);
    expect(assistantEdges.right, 48);
  });

  testWidgets('renders assistant markdown with code block', (tester) async {
    final msg = _assistantMessage(content: '```\ncode here\n```');
    await pumpBubble(tester, ChatMessageBubble(message: msg));

    expect(find.textContaining('code here'), findsOneWidget);
  });

  testWidgets('renders assistant markdown with heading', (tester) async {
    final msg = _assistantMessage(content: '## My Heading');
    await pumpBubble(tester, ChatMessageBubble(message: msg));

    expect(find.text('My Heading'), findsOneWidget);
  });
}
