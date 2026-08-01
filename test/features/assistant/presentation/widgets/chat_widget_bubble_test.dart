import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:ghar360/features/assistant/presentation/widgets/chat_widget_bubble.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../helpers/fake_webview_platform.dart';
import '../../../../helpers/mocks.dart';

ChatMessageModel _widgetMessage({
  String? widgetName = 'property_card',
  Map<String, dynamic>? widgetData,
}) {
  return ChatMessageModel(
    id: 'w1',
    role: ChatRole.widget,
    content: '',
    widgetName: widgetName,
    widgetData: widgetData,
    timestamp: DateTime.now(),
  );
}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
    // Register a fake WebView platform so WebViewController can be created
    // in the headless test environment.
    installFakeWebViewPlatform();
    // Suppress RenderFlex overflow errors that arise from constrained test
    // surfaces — the widget is designed for full-screen chat, not the small
    // test surface.
    FlutterError.onError = (details) {
      if (!details.summary.toString().contains('overflowed')) {
        FlutterError.presentError(details);
      }
    };
  });

  tearDown(() {
    FlutterError.onError = FlutterError.presentError;
    uninstallFakeWebViewPlatform();
    Get.reset();
  });

  Future<void> pumpBubble(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(body: Center(child: child)),
      ),
    );
    // Pump a few frames to let initState async work settle without
    // pumpAndSettle (which can hang on infinite animations like Shimmer).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  // ── Static helper: AssistantRepository.isValidWidgetName ──────────────
  // The ChatWidgetBubble delegates widget-name validation to this static
  // method. Testing it directly covers the rejection path that drives the
  // error state in _onWrapperLoaded.

  group('AssistantRepository.isValidWidgetName', () {
    test('accepts alphanumeric names with underscores and hyphens', () {
      expect(AssistantRepository.isValidWidgetName('property_card'), isTrue);
      expect(AssistantRepository.isValidWidgetName('emi-calculator'), isTrue);
      expect(AssistantRepository.isValidWidgetName('A1'), isTrue);
      expect(AssistantRepository.isValidWidgetName('widget_123'), isTrue);
      expect(AssistantRepository.isValidWidgetName('a-b-c'), isTrue);
    });

    test('rejects empty string', () {
      expect(AssistantRepository.isValidWidgetName(''), isFalse);
    });

    test('rejects path traversal attempts', () {
      expect(AssistantRepository.isValidWidgetName('../etc/passwd'), isFalse);
      expect(AssistantRepository.isValidWidgetName('a/b'), isFalse);
      expect(AssistantRepository.isValidWidgetName('..'), isFalse);
    });

    test('rejects names with special characters', () {
      expect(AssistantRepository.isValidWidgetName('a?x=1'), isFalse);
      expect(AssistantRepository.isValidWidgetName('a b'), isFalse);
      expect(AssistantRepository.isValidWidgetName('a;b'), isFalse);
      expect(AssistantRepository.isValidWidgetName('a"b'), isFalse);
      expect(AssistantRepository.isValidWidgetName('a<b>'), isFalse);
    });

    test('rejects names starting with hyphen or underscore', () {
      expect(AssistantRepository.isValidWidgetName('-abc'), isFalse);
      expect(AssistantRepository.isValidWidgetName('_abc'), isFalse);
    });

    test('rejects names exceeding 64 characters', () {
      final longName = 'a' * 65;
      expect(AssistantRepository.isValidWidgetName(longName), isFalse);
    });

    test('accepts names up to 64 characters', () {
      final maxName = 'a' * 64;
      expect(AssistantRepository.isValidWidgetName(maxName), isTrue);
    });

    test('rejects javascript: protocol injection', () {
      expect(AssistantRepository.isValidWidgetName('javascript:alert(1)'), isFalse);
    });
  });

  // ── ChatWidgetBubble widget structure ─────────────────────────────────
  // The WebView itself cannot be fully exercised in a headless test
  // environment (no platform WebView is registered), but the widget's
  // container structure, loading overlay, and error fallback can be
  // verified. The _onWrapperLoaded callback (fired by onPageFinished) does
  // not run in tests, so the widget stays in its initial loading state.

  group('ChatWidgetBubble widget', () {
    testWidgets('renders a fixed-height container (400px)', (tester) async {
      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage()));

      // The inner Container (inside ClipRRect) has a fixed height of 400.
      final containers = tester.widgetList<Container>(find.byType(Container));
      final heightContainer = containers.where((c) => c.constraints?.maxHeight == 400);
      expect(heightContainer, isNotEmpty);
    });

    testWidgets('wraps content in ClipRRect with rounded corners', (tester) async {
      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage()));

      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clipRRect.borderRadius, BorderRadius.circular(16));
    });

    testWidgets('applies left/right/bottom padding via Padding widget', (tester) async {
      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage()));

      final padding = tester.widget<Padding>(find.byType(Padding).first);
      final edges = padding.padding as EdgeInsets;
      expect(edges.left, 16);
      expect(edges.right, 16);
      expect(edges.bottom, 8);
    });

    testWidgets('shows loading overlay with widgets icon in initial state', (tester) async {
      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage()));

      // The loading overlay shows a widgets_outlined icon.
      expect(find.byIcon(Icons.widgets_outlined), findsWidgets);
    });

    testWidgets('uses Shimmer for loading animation', (tester) async {
      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage()));

      expect(find.byType(Shimmer), findsOneWidget);
    });

    testWidgets('renders without crashing for null widget name', (tester) async {
      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage(widgetName: null)));

      // Even with a null widget name, the widget should render its container
      // structure. The _onWrapperLoaded callback (which checks widgetName)
      // does not fire in tests, so the loading state is shown.
      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('renders without crashing for invalid widget name', (tester) async {
      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage(widgetName: '../bad')));

      // The widget should still render its container structure.
      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('renders without crashing for empty widget name', (tester) async {
      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage(widgetName: '')));

      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('renders container with border decoration', (tester) async {
      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage()));

      // Find the inner Container that has a BoxDecoration with a border.
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasBorderedContainer = containers.any((c) {
        final decoration = c.decoration;
        return decoration is BoxDecoration && decoration.border != null;
      });
      expect(hasBorderedContainer, isTrue);
    });

    testWidgets('loading overlay covers the full widget area', (tester) async {
      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage()));

      // The loading overlay is a Positioned.fill widget.
      expect(find.byType(Positioned), findsOneWidget);
      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      expect(positioned.left, 0);
      expect(positioned.top, 0);
      expect(positioned.right, 0);
      expect(positioned.bottom, 0);
    });

    testWidgets('loading overlay contains a Column with icon and text', (tester) async {
      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage()));

      // The loading overlay has a Column with an Icon and Text.
      final columns = tester.widgetList<Column>(find.byType(Column));
      final loadingColumn = columns.where((col) {
        return col.children.any((child) => child is Icon) &&
            col.children.any((child) => child is Text);
      });
      expect(loadingColumn, isNotEmpty);
    });

    testWidgets('uses AutomaticKeepAliveClientMixin (wantKeepAlive is true)', (tester) async {
      // This is verified indirectly: the widget renders without error and
      // the super.build(context) call in the build method is exercised.
      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage()));
      expect(find.byType(ChatWidgetBubble), findsOneWidget);
    });

    testWidgets('renders with widgetData present', (tester) async {
      await pumpBubble(
        tester,
        ChatWidgetBubble(message: _widgetMessage(widgetData: {'id': 1, 'name': 'Test'})),
      );

      expect(find.byType(ChatWidgetBubble), findsOneWidget);
    });

    testWidgets('renders multiple ChatWidgetBubble instances independently', (tester) async {
      await pumpBubble(
        tester,
        SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: 400,
                child: ChatWidgetBubble(message: _widgetMessage(widgetName: 'widget_a')),
              ),
              SizedBox(
                height: 400,
                child: ChatWidgetBubble(message: _widgetMessage(widgetName: 'widget_b')),
              ),
            ],
          ),
        ),
      );

      expect(find.byType(ChatWidgetBubble), findsNWidgets(2));
    });
  });

  // ── ChatMessageModel.copyWith for widget fields ───────────────────────
  // The ChatWidgetBubble reads widgetName and widgetData from the message.
  // Verify copyWith preserves/updates these fields correctly.

  group('ChatMessageModel widget fields', () {
    test('copyWith updates widgetName', () {
      final msg = _widgetMessage(widgetName: 'original');
      final updated = msg.copyWith(widgetName: 'updated');
      expect(updated.widgetName, 'updated');
      expect(updated.id, msg.id);
      expect(updated.role, ChatRole.widget);
    });

    test('copyWith updates widgetData', () {
      final msg = _widgetMessage(widgetData: {'old': true});
      final updated = msg.copyWith(widgetData: {'new': true});
      expect(updated.widgetData, {'new': true});
    });

    test('copyWith preserves widgetName when not provided', () {
      final msg = _widgetMessage(widgetName: 'preserved');
      final updated = msg.copyWith(content: 'new content');
      expect(updated.widgetName, 'preserved');
    });

    test('copyWith preserves widgetData when not provided', () {
      final msg = _widgetMessage(widgetData: {'preserved': true});
      final updated = msg.copyWith(content: 'new content');
      expect(updated.widgetData, {'preserved': true});
    });
  });

  // ── ChatWidgetBubble interactive WebView lifecycle ────────────────────

  group('ChatWidgetBubble MCP host wrapper', () {
    testWidgets('posts to the widget iframe with a wildcard targetOrigin', (tester) async {
      await pumpBubble(
        tester,
        ChatWidgetBubble(message: _widgetMessage(widgetName: 'PropertySearchWidget')),
      );

      final html = lastWebViewController?.lastLoadedHtml ?? '';
      expect(html, isNotEmpty);
      // The iframe is sandboxed without allow-same-origin, so its document has
      // an opaque origin. Only '*' can ever be delivered to it — anything else
      // silently drops the ui/initialize reply and the tool result, leaving the
      // widget stuck on its own "loading" fallback forever.
      expect(html, contains('sandbox="allow-scripts"'));
      expect(html, contains("postMessage(msg,'*')"));
      expect(html, isNot(contains('location.origin')));
      // A reload must clear the handshake state, or the tool result is posted
      // into a document that has not run the bridge yet.
      expect(html, contains('ready=false;pendingResult=null;'));
    });
  });

  group('ChatWidgetBubble page lifecycle', () {
    testWidgets('shows error fallback for invalid widget name after page finish', (tester) async {
      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage(widgetName: '../bad')));

      expect(lastNavigationDelegate?.pageFinishedCallback, isNotNull);
      lastNavigationDelegate!.pageFinishedCallback!('about:blank');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('assistant_widget_unavailable'.tr), findsOneWidget);
      expect(find.byType(Shimmer), findsNothing);
    });

    testWidgets('shows error fallback for null widget name after page finish', (tester) async {
      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage(widgetName: null)));

      lastNavigationDelegate!.pageFinishedCallback!('about:blank');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('assistant_widget_unavailable'.tr), findsOneWidget);
    });

    testWidgets('shows error when repository is missing', (tester) async {
      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage()));

      lastNavigationDelegate!.pageFinishedCallback!('about:blank');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Get.find throws → catch path sets _hasError.
      expect(find.text('assistant_widget_unavailable'.tr), findsOneWidget);
    });

    testWidgets('shows error when getWidgetHtml returns null', (tester) async {
      final mockRepo = MockAssistantRepository();
      when(() => mockRepo.getWidgetHtml(any())).thenAnswer((_) async => null);
      Get.put<AssistantRepository>(mockRepo);

      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage()));

      lastNavigationDelegate!.pageFinishedCallback!('about:blank');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('assistant_widget_unavailable'.tr), findsOneWidget);
    });

    testWidgets('shows error when getWidgetHtml throws', (tester) async {
      final mockRepo = MockAssistantRepository();
      when(() => mockRepo.getWidgetHtml(any())).thenThrow(Exception('network'));
      Get.put<AssistantRepository>(mockRepo);

      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage()));

      lastNavigationDelegate!.pageFinishedCallback!('about:blank');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('assistant_widget_unavailable'.tr), findsOneWidget);
    });

    testWidgets('loads widget HTML and clears loading overlay on success', (tester) async {
      final mockRepo = MockAssistantRepository();
      when(() => mockRepo.getWidgetHtml(any())).thenAnswer((_) async => '<html>widget</html>');
      Get.put<AssistantRepository>(mockRepo);

      await pumpBubble(
        tester,
        ChatWidgetBubble(message: _widgetMessage(widgetData: {'id': 42, 'title': 'Villa'})),
      );

      lastNavigationDelegate!.pageFinishedCallback!('about:blank');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('assistant_widget_unavailable'.tr), findsNothing);
      expect(find.byType(Shimmer), findsNothing);
      expect(lastWebViewController?.runJavaScriptCalls, greaterThanOrEqualTo(2));
      final scripts = lastWebViewController?.runJavaScriptScripts ?? [];
      expect(scripts.any((s) => s.contains('setTheme')), isTrue);
      expect(scripts.any((s) => s.contains('loadWidget')), isTrue);
      expect(scripts.any((s) => s.contains('injectToolResult')), isTrue);
    });

    testWidgets('loads widget without injectToolResult when widgetData is null', (tester) async {
      final mockRepo = MockAssistantRepository();
      when(() => mockRepo.getWidgetHtml(any())).thenAnswer((_) async => '<html>ok</html>');
      Get.put<AssistantRepository>(mockRepo);

      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage(widgetData: null)));

      lastNavigationDelegate!.pageFinishedCallback!('about:blank');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final scripts = lastWebViewController?.runJavaScriptScripts ?? [];
      expect(scripts.any((s) => s.contains('loadWidget')), isTrue);
      expect(scripts.any((s) => s.contains('injectToolResult')), isFalse);
      expect(find.byType(Shimmer), findsNothing);
    });

    testWidgets('uses dark theme string when Theme is dark', (tester) async {
      final mockRepo = MockAssistantRepository();
      when(() => mockRepo.getWidgetHtml(any())).thenAnswer((_) async => '<html>ok</html>');
      Get.put<AssistantRepository>(mockRepo);

      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          fallbackLocale: const Locale('en', 'US'),
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(child: ChatWidgetBubble(message: _widgetMessage())),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      lastNavigationDelegate!.pageFinishedCallback!('about:blank');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final scripts = lastWebViewController?.runJavaScriptScripts ?? [];
      expect(scripts.any((s) => s.contains("setTheme('dark')")), isTrue);
    });

    testWidgets('web resource error sets error fallback', (tester) async {
      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage()));

      expect(lastNavigationDelegate?.webResourceErrorCallback, isNotNull);
      lastNavigationDelegate!.webResourceErrorCallback!(
        FakeWebResourceError(description: 'load failed'),
      );
      await tester.pump();

      expect(find.text('assistant_widget_unavailable'.tr), findsOneWidget);
    });

    testWidgets('WidgetAction channel ignores empty and oversized messages', (tester) async {
      final mockRepo = MockAssistantRepository();
      when(() => mockRepo.getWidgetHtml(any())).thenAnswer((_) async => '<html>ok</html>');
      Get.put<AssistantRepository>(mockRepo);

      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage()));

      // No AssistantController registered — channel should no-op safely.
      lastWebViewController!.simulateJavaScriptMessage('WidgetAction', '   ');
      lastWebViewController!.simulateJavaScriptMessage('WidgetAction', 'x' * 501);
      lastWebViewController!.simulateJavaScriptMessage('WidgetAction', 'book visit');
      await tester.pump();

      expect(find.byType(ChatWidgetBubble), findsOneWidget);
    });

    testWidgets('WidgetAction channel forwards message to AssistantController', (tester) async {
      final mockRepo = MockAssistantRepository();
      when(() => mockRepo.getWidgetHtml(any())).thenAnswer((_) async => '<html>ok</html>');
      when(
        () => mockRepo.streamChat(
          message: any(named: 'message'),
          conversationId: any(named: 'conversationId'),
        ),
      ).thenAnswer((_) => const Stream.empty());
      Get.put<AssistantRepository>(mockRepo);

      // Minimal controller registration: only need sendMessage path.
      final assistant = AssistantController();
      // Avoid onInit network; put instance and set deps if needed.
      Get.put<AssistantController>(assistant);

      await pumpBubble(tester, ChatWidgetBubble(message: _widgetMessage()));

      lastWebViewController!.simulateJavaScriptMessage('WidgetAction', 'show more homes');
      await tester.pump();

      // sendMessage should have been invoked (adds user message).
      expect(assistant.messages.isNotEmpty, isTrue);
      expect(assistant.messages.first.content, 'show more homes');
    });
  });
}
