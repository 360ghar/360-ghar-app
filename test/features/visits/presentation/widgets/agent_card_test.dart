import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/data/models/agent_model.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/visits/presentation/widgets/agent_card.dart';
import '../../../../helpers/getx_test_binding.dart';

AgentModel _testAgent({
  String name = 'Jane Smith',
  String? avatarUrl,
  ExperienceLevel experienceLevel = ExperienceLevel.expert,
  double rating = 4.8,
}) {
  return AgentModel(
    id: 1,
    name: name,
    avatarUrl: avatarUrl,
    agentType: AgentType.senior,
    experienceLevel: experienceLevel,
    userSatisfactionRating: rating,
    createdAt: DateTime(2024, 1, 1),
  );
}

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpCard(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(
          body: Center(child: SizedBox(width: 400, child: child)),
        ),
      ),
    );
  }

  testWidgets('renders agent name', (tester) async {
    await pumpCard(tester, AgentCard(agent: _testAgent()));

    expect(find.text('Jane Smith'), findsOneWidget);
  });

  testWidgets('renders relationship manager label', (tester) async {
    await pumpCard(tester, AgentCard(agent: _testAgent()));

    // 'Your Relationship Manager'.tr returns the key itself when no
    // translation is registered for that exact string.
    expect(find.text('Your Relationship Manager'), findsOneWidget);
  });

  testWidgets('renders satisfaction rating with star icon', (tester) async {
    await pumpCard(tester, AgentCard(agent: _testAgent(rating: 4.8)));

    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
  });

  testWidgets('renders experience level string', (tester) async {
    await pumpCard(tester, AgentCard(agent: _testAgent()));

    expect(find.byIcon(Icons.work_outline), findsOneWidget);
    expect(find.text('Expert'), findsOneWidget);
  });

  testWidgets('renders call and whatsapp buttons with tooltips', (tester) async {
    await pumpCard(tester, AgentCard(agent: _testAgent()));

    expect(find.byIcon(Icons.phone), findsOneWidget);
    expect(find.byIcon(Icons.message), findsOneWidget);
    expect(find.byTooltip('Call'), findsOneWidget);
    expect(find.byTooltip('WhatsApp'), findsOneWidget);
  });

  testWidgets('calls onCall callback when call button tapped', (tester) async {
    var callCount = 0;
    await pumpCard(tester, AgentCard(agent: _testAgent(), onCall: () => callCount++));

    await tester.tap(find.byIcon(Icons.phone));
    await tester.pump();

    expect(callCount, 1);
  });

  testWidgets('calls onWhatsApp callback when whatsapp button tapped', (tester) async {
    var waCount = 0;
    await pumpCard(tester, AgentCard(agent: _testAgent(), onWhatsApp: () => waCount++));

    await tester.tap(find.byIcon(Icons.message));
    await tester.pump();

    expect(waCount, 1);
  });

  testWidgets('does not crash when onCall and onWhatsApp are null', (tester) async {
    await pumpCard(tester, AgentCard(agent: _testAgent()));

    // Tapping should not throw even with null callbacks (defaults to no-op).
    await tester.tap(find.byIcon(Icons.phone));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.message));
    await tester.pump();

    // No exception thrown means the test passes.
  });

  testWidgets('shows person icon placeholder when avatarUrl is null', (tester) async {
    await pumpCard(tester, AgentCard(agent: _testAgent(avatarUrl: null)));

    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('renders beginner experience level', (tester) async {
    await pumpCard(tester, AgentCard(agent: _testAgent(experienceLevel: ExperienceLevel.beginner)));

    expect(find.text('Beginner'), findsOneWidget);
  });

  testWidgets('renders intermediate experience level', (tester) async {
    await pumpCard(
      tester,
      AgentCard(agent: _testAgent(experienceLevel: ExperienceLevel.intermediate)),
    );

    expect(find.text('Intermediate'), findsOneWidget);
  });

  testWidgets('renders unknown experience level', (tester) async {
    await pumpCard(tester, AgentCard(agent: _testAgent(experienceLevel: ExperienceLevel.unknown)));

    expect(find.text('Unknown'), findsOneWidget);
  });
}
