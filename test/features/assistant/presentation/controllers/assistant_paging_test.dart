import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ghar360/core/bootstrap/provider_policy.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/data/models/assistant_frame.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:ghar360/features/assistant/data/models/conversation_model.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_history_controller.dart';
import '../../../../helpers/assistant_test_harness.dart';

ChatMessageModel _message(int id) => ChatMessageModel(
  id: '$id',
  role: id.isEven ? ChatRole.assistant : ChatRole.user,
  content: 'm$id',
  timestamp: DateTime.utc(2024, 1, 1, 0, 0, id),
);

ConversationModel _conversation(int id) => ConversationModel(
  id: id,
  title: 'Chat $id',
  createdAt: DateTime.utc(2024, 1, id),
  updatedAt: DateTime.utc(2024, 1, id),
  messageCount: 2,
);

void main() {
  group('messages paging', () {
    late AssistantTestHarness harness;
    setUp(() => harness = AssistantTestHarness());
    tearDown(() => harness.dispose());

    test('opens on the newest page and prepends older pages in order', () async {
      when(() => harness.repository.getMessagesPage(3)).thenAnswer(
        (_) async =>
            MessagesPage(items: [_message(3), _message(4)], hasMore: true, nextCursor: 'c1'),
      );
      when(
        () => harness.repository.getMessagesPage(3, cursor: 'c1'),
      ).thenAnswer((_) async => MessagesPage(items: [_message(1), _message(2)], hasMore: false));
      final controller = harness.conversation(3);
      await controller.loadMessages();
      expect(controller.snapshot.messages.map((m) => m.id), ['3', '4']);
      expect(controller.snapshot.hasOlder, isTrue);

      await controller.loadOlderMessages();

      expect(controller.snapshot.messages.map((m) => m.id), ['1', '2', '3', '4']);
      expect(controller.snapshot.hasOlder, isFalse);
      expect(controller.snapshot.olderStatus, OlderMessagesStatus.idle);
      // At the start of the conversation there is nothing more to ask for.
      await controller.loadOlderMessages();
      verify(() => harness.repository.getMessagesPage(3, cursor: 'c1')).called(1);
    });

    test('an older-page failure keeps the rows and the cursor for retry', () async {
      when(() => harness.repository.getMessagesPage(3)).thenAnswer(
        (_) async => MessagesPage(items: [_message(3)], hasMore: true, nextCursor: 'c1'),
      );
      when(
        () => harness.repository.getMessagesPage(3, cursor: 'c1'),
      ).thenThrow(NetworkException('offline'));
      final controller = harness.conversation(3);
      await controller.loadMessages();

      await controller.loadOlderMessages();

      expect(controller.snapshot.messages.map((m) => m.id), ['3']);
      expect(controller.snapshot.olderStatus, OlderMessagesStatus.failed);
      expect(controller.snapshot.olderCursor, 'c1');
      expect(controller.snapshot.loadStatus, ConversationLoadStatus.ready);

      when(
        () => harness.repository.getMessagesPage(3, cursor: 'c1'),
      ).thenAnswer((_) async => MessagesPage(items: [_message(1)], hasMore: false));
      await controller.loadOlderMessages();
      expect(controller.snapshot.messages.map((m) => m.id), ['1', '3']);
      expect(controller.snapshot.olderStatus, OlderMessagesStatus.idle);
    });

    test('an invalid cursor retries from the newest page', () async {
      var newest = 0;
      when(() => harness.repository.getMessagesPage(3)).thenAnswer((_) async {
        newest++;
        return MessagesPage(items: [_message(3)], hasMore: true, nextCursor: 'c$newest');
      });
      when(
        () => harness.repository.getMessagesPage(3, cursor: 'c1'),
      ).thenThrow(ApiException('Invalid cursor', statusCode: 400, code: 'INVALID_CURSOR'));
      final controller = harness.conversation(3);
      await controller.loadMessages();
      await controller.loadOlderMessages();
      expect(controller.snapshot.olderStatus, OlderMessagesStatus.failed);

      await controller.loadOlderMessages();

      expect(newest, 2);
      expect(controller.snapshot.olderCursor, 'c2');
      expect(controller.snapshot.olderStatus, OlderMessagesStatus.idle);
    });

    test('a late older page is dropped after the history is replaced', () async {
      final older = Completer<MessagesPage>();
      when(() => harness.repository.getMessagesPage(3)).thenAnswer(
        (_) async => MessagesPage(items: [_message(3)], hasMore: true, nextCursor: 'c1'),
      );
      when(
        () => harness.repository.getMessagesPage(3, cursor: 'c1'),
      ).thenAnswer((_) => older.future);
      final controller = harness.conversation(3);
      await controller.loadMessages();
      final pending = controller.loadOlderMessages();

      await controller.loadMessages();
      older.complete(MessagesPage(items: [_message(1)], hasMore: false));
      await pending;

      expect(controller.snapshot.messages.map((m) => m.id), ['3']);
      expect(controller.snapshot.olderStatus, OlderMessagesStatus.idle);
    });

    test('a send while an older page loads keeps both', () async {
      final older = Completer<MessagesPage>();
      final stream = StreamController<AssistantFrame>();
      addTearDown(stream.close);
      when(() => harness.repository.getMessagesPage(3)).thenAnswer(
        (_) async => MessagesPage(items: [_message(3)], hasMore: true, nextCursor: 'c1'),
      );
      when(
        () => harness.repository.getMessagesPage(3, cursor: 'c1'),
      ).thenAnswer((_) => older.future);
      when(
        () => harness.repository.streamChat(message: 'new', conversationId: 3),
      ).thenAnswer((_) => stream.stream);
      final controller = harness.conversation(3);
      await controller.loadMessages();
      final pending = controller.loadOlderMessages();

      controller.sendMessage('new');
      older.complete(MessagesPage(items: [_message(1)], hasMore: false));
      await pending;

      expect(controller.snapshot.messages.first.id, '1');
      expect(controller.snapshot.messages.map((m) => m.content), contains('new'));
      expect(controller.snapshot.isStreaming, isTrue);
    });
  });

  group('failed replies', () {
    late AssistantTestHarness harness;
    setUp(() => harness = AssistantTestHarness());
    tearDown(() => harness.dispose());

    test('retry after a failed reply sends the kept prompt again', () async {
      final first = StreamController<AssistantFrame>();
      final second = StreamController<AssistantFrame>();
      addTearDown(second.close);
      var calls = 0;
      when(
        () => harness.repository.streamChat(message: 'Book a visit', conversationId: null),
      ).thenAnswer((_) => ++calls == 1 ? first.stream : second.stream);
      final controller = harness.conversation();
      controller.sendMessage('Book a visit');
      first
        ..add(const TextChunkFrame('Partial'))
        ..add(const ErrorFrame(code: AssistantErrorCode.agentError, message: 'private'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.snapshot.streamStatus, AssistantStreamStatus.failed);
      expect(controller.snapshot.messages.map((m) => m.content), contains('Partial'));

      controller.retryLastPrompt();

      expect(calls, 2);
      expect(controller.snapshot.isStreaming, isTrue);
      expect(controller.snapshot.draft, isEmpty);
      await first.close();
    });

    test('after a tool ran, retry never resends; the prompt waits in the composer', () async {
      final first = StreamController<AssistantFrame>();
      var calls = 0;
      when(
        () => harness.repository.streamChat(message: 'Book a visit', conversationId: null),
      ).thenAnswer((_) {
        calls++;
        return first.stream;
      });
      final controller = harness.conversation();
      controller.sendMessage('Book a visit');
      first
        ..add(const ToolCallStartFrame(callId: 'call_1', tool: 'bookings_create'))
        ..add(const ErrorFrame(code: AssistantErrorCode.agentError, message: 'private'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.snapshot.streamStatus, AssistantStreamStatus.failed);
      expect(controller.snapshot.turnUsedTool, isTrue);
      expect(controller.snapshot.draft, 'Book a visit');

      controller.retryLastPrompt();

      expect(calls, 1, reason: 'the booking tool may already have acted');
      expect(controller.snapshot.isStreaming, isFalse);
      await first.close();
    });
  });

  group('history first-page cache', () {
    late AppDatabase database;
    late MockAssistantRepository repository;

    setUp(() async {
      sqfliteFfiInit();
      database = await AppDatabase.open(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
        legacyReader: () async => {},
      );
      repository = MockAssistantRepository();
    });
    tearDown(() => database.close());

    ProviderContainer visit() {
      final container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          assistantRepositoryProvider.overrideWithValue(repository),
          appDatabaseProvider.overrideWithValue(database),
          storageScopeProvider.overrideWith(() => _Scope(database)),
        ],
      );
      container.listen(assistantHistoryProvider, (_, _) {});
      return container;
    }

    test('a repeat visit shows the cached first page while it revalidates', () async {
      when(() => repository.getConversations()).thenAnswer(
        (_) async => ConversationsPage(
          items: [_conversation(1), _conversation(2)],
          hasMore: true,
          nextCursor: 'next',
        ),
      );
      final first = visit();
      await first.read(assistantHistoryProvider.notifier).loadConversations();
      first.dispose();

      final network = Completer<ConversationsPage>();
      when(() => repository.getConversations()).thenAnswer((_) => network.future);
      final second = visit();
      addTearDown(second.dispose);
      final load = second.read(assistantHistoryProvider.notifier).loadConversations();
      await pumpEventQueue();

      var state = second.read(assistantHistoryProvider);
      expect(state.conversations.map((c) => c.title), ['Chat 1', 'Chat 2']);
      // Refreshing, not loading: the sheet shows rows, never the skeleton.
      expect(state.status, HistoryLoadStatus.refreshing);
      expect(state.nextCursor, 'next');

      network.complete(ConversationsPage(items: [_conversation(3)], hasMore: false));
      await load;
      state = second.read(assistantHistoryProvider);
      expect(state.conversations.map((c) => c.id), [3]);
      expect(state.status, HistoryLoadStatus.ready);
    });

    test('a failed revalidation keeps the cached rows with an inline retry', () async {
      when(
        () => repository.getConversations(),
      ).thenAnswer((_) async => ConversationsPage(items: [_conversation(1)], hasMore: false));
      final first = visit();
      await first.read(assistantHistoryProvider.notifier).loadConversations();
      first.dispose();

      when(() => repository.getConversations()).thenThrow(NetworkException('offline'));
      final second = visit();
      addTearDown(second.dispose);
      await second.read(assistantHistoryProvider.notifier).loadConversations();

      final state = second.read(assistantHistoryProvider);
      expect(state.conversations.map((c) => c.id), [1]);
      expect(state.status, HistoryLoadStatus.refreshFailed);
      expect(state.error, isA<NetworkException>());
    });

    test('a delete removes the row from the cache too', () async {
      when(() => repository.getConversations()).thenAnswer(
        (_) async => ConversationsPage(items: [_conversation(1), _conversation(2)], hasMore: false),
      );
      when(() => repository.deleteConversation(1)).thenAnswer((_) async => true);
      final first = visit();
      await first.read(assistantHistoryProvider.notifier).loadConversations();
      expect(await first.read(assistantHistoryProvider.notifier).deleteConversation(1), isTrue);
      first.dispose();

      when(
        () => repository.getConversations(),
      ).thenAnswer((_) => Completer<ConversationsPage>().future);
      final second = visit();
      addTearDown(second.dispose);
      unawaited(second.read(assistantHistoryProvider.notifier).loadConversations());
      await pumpEventQueue();

      expect(second.read(assistantHistoryProvider).conversations.map((c) => c.id), [2]);
    });
  });
}

class _Scope extends StorageScopeNotifier {
  _Scope(this.database);
  final AppDatabase database;
  @override
  StorageScope build() => database.activateScope(environment: 'test', accountId: 'account-a');
}
