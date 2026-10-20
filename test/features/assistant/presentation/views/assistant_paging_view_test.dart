import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/data/models/assistant_frame.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:ghar360/features/assistant/data/models/conversation_model.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_history_controller.dart';
import 'package:ghar360/features/assistant/presentation/views/assistant_view.dart';
import '../../../../helpers/assistant_test_harness.dart';
import '../../../../helpers/fake_webview_platform.dart';
import '../../../../helpers/provider_test_app.dart';

ChatMessageModel _message(int id, {String? content}) => ChatMessageModel(
  id: '$id',
  role: id.isEven ? ChatRole.assistant : ChatRole.user,
  content: content ?? 'Message number $id',
  timestamp: DateTime.utc(2024, 1, 1, 0, 0, id),
);

ConversationModel _conversation(int id) => ConversationModel(
  id: id,
  title: 'Chat about flat $id in Sector ${40 + id}',
  createdAt: DateTime.utc(2024, 1, 1),
  updatedAt: DateTime.utc(2024, 3, 1 + id % 27),
  messageCount: id,
);

void main() {
  late AssistantTestHarness harness;
  setUp(() {
    installFakeWebViewPlatform();
    harness = AssistantTestHarness();
  });
  tearDown(() {
    uninstallFakeWebViewPlatform();
    harness.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    int? conversationId,
    Locale locale = const Locale('en', 'US'),
    double textScale = 1,
    ThemeData? theme,
  }) async {
    await tester.pumpProviderApp(
      UncontrolledProviderScope(
        container: harness.container,
        child: AssistantView(conversationId: conversationId),
      ),
      locale: locale,
      textScale: textScale,
      theme: theme,
    );
    await tester.pump();
  }

  group('older messages', () {
    testWidgets('scrolling to the top loads the page before without moving the reader', (
      tester,
    ) async {
      final older = Completer<MessagesPage>();
      when(
        () => harness.repository.getMessagesPage(3, cursor: 'c1'),
      ).thenAnswer((_) => older.future);
      harness
          .conversation(3)
          .seed(
            AssistantState(
              conversationId: 3,
              loadStatus: ConversationLoadStatus.ready,
              messages: [for (var id = 11; id <= 50; id++) _message(id)],
              olderCursor: 'c1',
            ),
          );
      await pump(tester, conversationId: 3);
      verifyNever(() => harness.repository.getMessagesPage(3, cursor: 'c1'));

      final list = find.byKey(const ValueKey('qa.assistant.message_list'));
      await tester.dragUntilVisible(find.text('Message number 13'), list, const Offset(0, 300));
      await tester.pump();
      verify(() => harness.repository.getMessagesPage(3, cursor: 'c1')).called(1);
      final anchor = tester.getTopLeft(find.text('Message number 13'));

      older.complete(
        MessagesPage(items: [for (var id = 1; id <= 10; id++) _message(id)], hasMore: false),
      );
      await tester.pump();
      await tester.pump();

      // Rows arrive above the reader; the message they were reading stays put.
      expect(tester.getTopLeft(find.text('Message number 13')), anchor);
      await tester.dragUntilVisible(find.text('Message number 1'), list, const Offset(0, 300));
      expect(find.text('Message number 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.assistant.load_earlier')), findsNothing);
    });

    testWidgets('an older-page failure is a retry row above the kept messages', (tester) async {
      when(
        () => harness.repository.getMessagesPage(3, cursor: 'c1'),
      ).thenThrow(NetworkException('offline'));
      harness
          .conversation(3)
          .seed(
            AssistantState(
              conversationId: 3,
              loadStatus: ConversationLoadStatus.ready,
              messages: [_message(1), _message(2)],
              olderCursor: 'c1',
            ),
          );
      await pump(tester, conversationId: 3);
      await tester.pump();

      expect(find.byKey(const ValueKey('assistant_older_failed')), findsOneWidget);
      expect(find.text('Message number 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.state.error.action')), findsNothing);

      when(() => harness.repository.getMessagesPage(3, cursor: 'c1')).thenAnswer(
        (_) async => MessagesPage(items: [_message(-1, content: 'Earlier')], hasMore: false),
      );
      await tester.tap(find.byKey(const ValueKey('qa.assistant.older_retry')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Earlier'), findsOneWidget);
      expect(find.byKey(const ValueKey('assistant_older_failed')), findsNothing);
    });

    testWidgets('a stream failure keeps the partial reply and retries the prompt', (tester) async {
      final first = StreamController<AssistantFrame>();
      final second = StreamController<AssistantFrame>();
      addTearDown(() => unawaited(second.close()));
      var calls = 0;
      when(
        () => harness.repository.streamChat(message: 'Two BHK near metro', conversationId: null),
      ).thenAnswer((_) => ++calls == 1 ? first.stream : second.stream);
      harness.conversation().seed(AssistantState(loadStatus: ConversationLoadStatus.ready));
      await pump(tester);
      harness.conversation().sendMessage('Two BHK near metro');
      first
        ..add(const TextChunkFrame('Looking at Sector'))
        ..add(const ErrorFrame(code: AssistantErrorCode.agentError, message: 'secret'));
      await tester.pump();

      expect(find.text('Looking at Sector'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('qa.assistant.stream_retry')));
      await tester.pump();
      expect(calls, 2);
      expect(find.byKey(const ValueKey('qa.assistant.stream_retry')), findsNothing);
      unawaited(first.close());
      await tester.pump();
    });
  });

  group('history sheet', () {
    Future<void> openHistory(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('qa.assistant.history')));
      await tester.pumpAndSettle();
    }

    testWidgets('loads the next page near the end, keeps rows, and retries inline', (tester) async {
      when(() => harness.repository.getConversations()).thenAnswer(
        (_) async => ConversationsPage(
          items: [for (var id = 1; id <= 20; id++) _conversation(id)],
          hasMore: true,
          nextCursor: 'n1',
        ),
      );
      when(
        () => harness.repository.getConversations(cursor: 'n1'),
      ).thenThrow(NetworkException('offline'));
      harness.conversation().seed(AssistantState(loadStatus: ConversationLoadStatus.ready));
      await pump(tester);
      await openHistory(tester);
      verifyNever(() => harness.repository.getConversations(cursor: 'n1'));

      final list = find.byKey(const ValueKey('qa.assistant.history.list'));
      await tester.fling(list, const Offset(0, -3000), 3000);
      await tester.pumpAndSettle();

      verify(() => harness.repository.getConversations(cursor: 'n1')).called(1);
      expect(find.byKey(const ValueKey('assistant_history_page_failed')), findsOneWidget);
      expect(find.text('Chat about flat 20 in Sector 60'), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.state.error.action')), findsNothing);

      when(
        () => harness.repository.getConversations(cursor: 'n1'),
      ).thenAnswer((_) async => ConversationsPage(items: [_conversation(21)], hasMore: false));
      await tester.tap(find.byKey(const ValueKey('qa.assistant.history.page_retry')));
      await tester.pumpAndSettle();
      await tester.fling(list, const Offset(0, -3000), 3000);
      await tester.pumpAndSettle();
      expect(find.text('Chat about flat 21 in Sector 61'), findsOneWidget);
      expect(find.byKey(const ValueKey('assistant_history_page_failed')), findsNothing);
    });

    testWidgets('the Load more button asks for the next page', (tester) async {
      // A failed refresh keeps the rows and turns automatic paging off; the
      // button is then the way to the next page.
      when(() => harness.repository.getConversations()).thenThrow(NetworkException('offline'));
      when(
        () => harness.repository.getConversations(cursor: 'n1'),
      ).thenAnswer((_) async => ConversationsPage(items: [_conversation(4)], hasMore: false));
      harness.history().seed(
        AssistantHistoryState(
          conversations: [for (var id = 1; id <= 3; id++) _conversation(id)],
          status: HistoryLoadStatus.refreshFailed,
          hasMore: true,
          nextCursor: 'n1',
        ),
      );
      harness.conversation().seed(AssistantState(loadStatus: ConversationLoadStatus.ready));
      await pump(tester);
      await openHistory(tester);
      expect(find.byKey(const ValueKey('assistant_history_failed')), findsOneWidget);
      verifyNever(() => harness.repository.getConversations(cursor: 'n1'));

      await tester.tap(find.byKey(const ValueKey('qa.assistant.history.load_more')));
      await tester.pumpAndSettle();

      verify(() => harness.repository.getConversations(cursor: 'n1')).called(1);
      expect(find.text('Chat about flat 4 in Sector 44'), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.assistant.history.load_more')), findsNothing);
    });

    testWidgets('an empty history offers one way forward', (tester) async {
      when(
        () => harness.repository.getConversations(),
      ).thenAnswer((_) async => const ConversationsPage(items: [], hasMore: false));
      harness.conversation().seed(AssistantState(loadStatus: ConversationLoadStatus.ready));
      await pump(tester);
      await openHistory(tester);

      expect(find.byKey(const ValueKey('qa.state.empty.action')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('qa.state.empty.action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('qa.assistant.history.list')), findsNothing);
    });
  });

  group('narrow Hindi 2x', () {
    for (final dark in [true, false]) {
      final mode = dark ? 'dark' : 'light';
      Future<void> narrow(WidgetTester tester, {int? conversationId}) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pump(
          tester,
          conversationId: conversationId,
          locale: const Locale('hi', 'IN'),
          textScale: 2,
          theme: dark ? AppDesignTheme.dark() : AppDesignTheme.light(),
        );
        await tester.pump(const Duration(milliseconds: 200));
      }

      testWidgets('new chat with prompts fits in $mode', (tester) async {
        harness.conversation().seed(AssistantState(loadStatus: ConversationLoadStatus.ready));
        await narrow(tester);
        expect(tester.takeException(), isNull);
        await tester.fling(find.byType(Scrollable).first, const Offset(0, -2000), 3000);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('conversation with every recovery row fits in $mode', (tester) async {
        when(
          () => harness.repository.getMessagesPage(3, cursor: 'c1'),
        ).thenThrow(NetworkException('offline'));
        harness
            .conversation(3)
            .seed(
              AssistantState(
                conversationId: 3,
                loadStatus: ConversationLoadStatus.ready,
                messages: [
                  _message(1, content: 'सेक्टर 45 में दो बेडरूम का फ्लैट दिखाइए'),
                  _message(
                    2,
                    content:
                        '## तीन घर मिले\n\n**₹42,000/माह** · सेक्टर 45 · 1,250 वर्ग फुट\n\n- मेट्रो के पास\n- पार्किंग',
                  ),
                ],
                olderCursor: 'c1',
                draft: 'बालकनी वाला भी',
                streamStatus: AssistantStreamStatus.failed,
                activeToolCalls: {'call_1': 'discovery_search'},
                storageError: Exception('disk'),
              ),
            );
        await narrow(tester, conversationId: 3);
        await tester.pump();
        expect(tester.takeException(), isNull);
        // Reach the oldest shown message: the older page loads, fails, and its
        // retry row must fit too.
        await tester.fling(
          find.byKey(const ValueKey('qa.assistant.message_list')),
          const Offset(0, 3000),
          3000,
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('assistant_older_failed')), findsOneWidget);
      });

      testWidgets('history rows and a page failure fit in $mode', (tester) async {
        when(() => harness.repository.getConversations()).thenAnswer(
          (_) async => ConversationsPage(
            items: [for (var id = 1; id <= 6; id++) _conversation(id)],
            hasMore: true,
            nextCursor: 'n1',
          ),
        );
        when(
          () => harness.repository.getConversations(cursor: 'n1'),
        ).thenThrow(NetworkException('offline'));
        harness.conversation().seed(AssistantState(loadStatus: ConversationLoadStatus.ready));
        await narrow(tester);
        await tester.tap(find.byKey(const ValueKey('qa.assistant.history')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.fling(
          find.byKey(const ValueKey('qa.assistant.history.list')),
          const Offset(0, -3000),
          3000,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('assistant_history_page_failed')), findsOneWidget);
      });

      testWidgets('empty and failed history fit in $mode', (tester) async {
        when(() => harness.repository.getConversations()).thenThrow(ServerException('down'));
        harness.conversation().seed(AssistantState(loadStatus: ConversationLoadStatus.ready));
        await narrow(tester);
        await tester.tap(find.byKey(const ValueKey('qa.assistant.history')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('assistant_history_failed')), findsOneWidget);

        when(
          () => harness.repository.getConversations(),
        ).thenAnswer((_) async => const ConversationsPage(items: [], hasMore: false));
        await tester.ensureVisible(find.byKey(const ValueKey('qa.state.error.action')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('qa.state.error.action')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('qa.state.empty.action')), findsOneWidget);
      });
    }
  });
}
