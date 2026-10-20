import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/data/models/assistant_frame.dart';
import 'package:ghar360/features/assistant/data/models/conversation_model.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_history_controller.dart';
import '../../../../helpers/assistant_test_harness.dart';

ConversationModel _conversation(int id) =>
    ConversationModel(id: id, createdAt: DateTime.utc(2024), updatedAt: DateTime.utc(2024));

void main() {
  late AssistantTestHarness harness;
  setUp(() => harness = AssistantTestHarness());
  tearDown(() => harness.dispose());

  test('conversation families own independent messages and drafts', () async {
    final first = harness.conversation(1);
    final second = harness.conversation(2);
    first.updateDraft('First draft');
    second.updateDraft('Second draft');
    await Future.wait([first.saveDraft(), second.saveDraft()]);
    expect(first.snapshot.draft, 'First draft');
    expect(second.snapshot.draft, 'Second draft');
    expect(harness.database.drafts['test:account-a:assistant:1']?['text'], 'First draft');
    expect(harness.database.drafts['test:account-a:assistant:2']?['text'], 'Second draft');
  });

  test('draft failure preserves text and explicit retry recovers', () async {
    final controller = harness.conversation();
    harness.database.writeFailure = StorageFailure('disk full');
    controller.updateDraft('Keep this text');
    await controller.saveDraft();
    expect(controller.snapshot.draft, 'Keep this text');
    expect(controller.snapshot.storageError, isA<StorageFailure>());
    harness.database.writeFailure = null;
    await controller.saveDraft();
    expect(controller.snapshot.storageError, isNull);
    expect(harness.database.drafts.values.single['text'], 'Keep this text');
  });

  test('draft read failure blocks replacement and retries the read', () async {
    harness.database.drafts['test:account-a:assistant:new'] = {'text': 'Saved before restart'};
    harness.database.readFailure = StorageFailure('read failed');
    final controller = harness.conversation();
    await controller.initialize();
    expect(controller.snapshot.draftStatus, AssistantDraftStatus.readFailed);
    controller.updateDraft('Replacement');
    await controller.saveDraft();
    expect(harness.database.drafts.values.single['text'], 'Saved before restart');
    harness.database.readFailure = null;
    await controller.retryDraft();
    expect(controller.snapshot.draft, 'Saved before restart');
    expect(controller.snapshot.draftStatus, AssistantDraftStatus.ready);
  });

  test('interrupted response and prompt restore from persisted draft', () async {
    final stream = StreamController<AssistantFrame>();
    when(
      () => harness.repository.streamChat(message: 'Find a flat', conversationId: null),
    ).thenAnswer((_) => stream.stream);
    final controller = harness.conversation();
    controller.sendMessage('Find a flat');
    stream.add(const TextChunkFrame('Partial answer'));
    await Future<void>.value();
    controller.cancelStream();
    await controller.saveDraft();
    harness.container.invalidate(assistantControllerProvider(null));
    final restored = harness.conversation();
    await restored.initialize();
    expect(restored.snapshot.draft, 'Find a flat');
    expect(restored.snapshot.messages.last.content, 'Partial answer');
    expect(restored.snapshot.streamStatus, AssistantStreamStatus.interrupted);
    await stream.close();
  });

  test('account transition cancels stream and rejects delayed draft write', () async {
    final gate = Completer<void>();
    harness.database.beforeWrite = () => gate.future;
    final stream = StreamController<AssistantFrame>();
    when(
      () => harness.repository.streamChat(message: 'private', conversationId: null),
    ).thenAnswer((_) => stream.stream);
    final controller = harness.conversation();
    controller.sendMessage('private');
    final pendingWrite = controller.saveDraft();
    (harness.container.read(storageScopeProvider.notifier) as TestScopeNotifier).switchAccount(
      'account-b',
    );
    final fresh = harness.container.read(assistantControllerProvider(null));
    expect(fresh.messages, isEmpty);
    expect(fresh.draft, isEmpty);
    expect(stream.hasListener, isFalse);
    gate.complete();
    await pendingWrite;
    expect(harness.database.drafts, isEmpty);
    expect(harness.container.read(assistantControllerProvider(null)).storageError, isNull);
    await stream.close();
  });

  test('late conversation response cannot enter another account', () async {
    final result = Completer<MessagesPage>();
    when(() => harness.repository.getMessagesPage(4)).thenAnswer((_) => result.future);
    final controller = harness.conversation(4);
    final load = controller.loadMessages();
    (harness.container.read(storageScopeProvider.notifier) as TestScopeNotifier).switchAccount(
      'account-b',
    );
    harness.container.read(assistantControllerProvider(4));
    result.complete(const MessagesPage(items: [], hasMore: false));
    await load;
    expect(controller.snapshot.loadStatus, ConversationLoadStatus.initial);
    expect(controller.snapshot.messages, isEmpty);
  });

  test('history page failure keeps cursor and content for explicit retry', () async {
    final history = harness.history();
    when(() => harness.repository.getConversations()).thenAnswer(
      (_) async =>
          ConversationsPage(items: [_conversation(1)], nextCursor: 'page-2', hasMore: true),
    );
    when(
      () => harness.repository.getConversations(cursor: 'page-2'),
    ).thenThrow(Exception('network'));
    await history.loadConversations();
    await history.loadMoreConversations();
    expect(history.snapshot.status, HistoryLoadStatus.pageFailed);
    expect(history.snapshot.conversations.single.id, 1);
    expect(history.snapshot.nextCursor, 'page-2');
    when(() => harness.repository.getConversations(cursor: 'page-2')).thenAnswer(
      (_) async => ConversationsPage(
        items: [_conversation(1), _conversation(2), _conversation(2)],
        nextCursor: 'page-2',
        hasMore: true,
      ),
    );
    await history.loadMoreConversations();
    expect(history.snapshot.conversations.map((item) => item.id), [1, 2]);
    expect(history.snapshot.hasMore, isFalse);
    expect(history.snapshot.error, isNull);
  });

  test('confirmed delete removes drafts; cleanup retries without repeating deletion', () async {
    harness.database.drafts['test:account-a:assistant:4'] = {'text': 'private'};
    harness.database.drafts['test:account-a:assistant:new'] = {
      'conversation_id': 4,
      'text': 'private',
    };
    harness.database.writeFailure = StorageFailure('disk full');
    when(() => harness.repository.deleteConversation(4)).thenAnswer((_) async => true);
    final history = harness.history();
    expect(await history.deleteConversation(4), isTrue);
    expect(history.snapshot.cleanupId, 4);
    expect(history.snapshot.deleteError, isA<StorageFailure>());
    harness.database.writeFailure = null;
    await history.retryDraftCleanup();
    expect(harness.database.drafts, isEmpty);
    expect(history.snapshot.cleanupId, isNull);
    expect(history.snapshot.deleteError, isNull);
    verify(() => harness.repository.deleteConversation(4)).called(1);
  });

  test('refresh failure keeps history and delete failure stays separate', () async {
    final history = harness.history();
    when(
      () => harness.repository.getConversations(),
    ).thenAnswer((_) async => ConversationsPage(items: [_conversation(1)], hasMore: false));
    await history.loadConversations();
    when(() => harness.repository.getConversations()).thenThrow(Exception('offline'));
    await history.loadConversations();
    expect(history.snapshot.status, HistoryLoadStatus.refreshFailed);
    expect(history.snapshot.conversations.single.id, 1);
    when(() => harness.repository.deleteConversation(1)).thenAnswer((_) async => false);
    expect(await history.deleteConversation(1), isFalse);
    expect(history.snapshot.deleteError, isNotNull);
    expect(history.snapshot.conversations.single.id, 1);
    expect(history.snapshot.status, HistoryLoadStatus.refreshFailed);
  });
}
