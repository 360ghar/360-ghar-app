import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/agent_model.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/features/visits/presentation/widgets/agent_card.dart';
import '../../../../helpers/knife_finders.dart';
import '../../../../helpers/provider_test_app.dart';

AgentModel _testAgent({
  String name = 'Jane Smith',
  String? avatarUrl,
  ExperienceLevel? experienceLevel = ExperienceLevel.expert,
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
  Future<void> pumpCard(WidgetTester tester, Widget child) => tester.pumpProviderApp(
    Scaffold(
      body: Center(child: SizedBox(width: 400, child: child)),
    ),
  );

  testWidgets('renders agent name', (tester) async {
    await pumpCard(tester, AgentCard(agent: _testAgent()));

    expect(find.text('Jane Smith'), findsOneWidget);
  });

  testWidgets('renders relationship manager label', (tester) async {
    await pumpCard(tester, AgentCard(agent: _testAgent()));

    // The English catalog provides the relationship-manager label.
    expect(find.text('Your relationship manager'), findsOneWidget);
  });

  testWidgets('renders satisfaction rating with star icon', (tester) async {
    await pumpCard(tester, AgentCard(agent: _testAgent(rating: 4.8)));

    expect(findKnife(KnifeIcon.star), findsOneWidget);
    expect(find.textContaining('4.8', findRichText: true), findsOneWidget);
  });

  testWidgets('renders experience level string', (tester) async {
    await pumpCard(tester, AgentCard(agent: _testAgent()));

    expect(findKnife(KnifeIcon.briefcase), findsNothing);
    expect(find.textContaining('Expert', findRichText: true), findsOneWidget);
  });

  testWidgets('renders call and whatsapp buttons with tooltips', (tester) async {
    await pumpCard(tester, AgentCard(agent: _testAgent()));

    expect(findKnife(KnifeIcon.phone), findsOneWidget);
    expect(findKnife(KnifeIcon.chat), findsOneWidget);
    expect(find.byTooltip('Call'), findsOneWidget);
    expect(find.byTooltip('WhatsApp'), findsOneWidget);
  });

  testWidgets('calls onCall callback when call button tapped', (tester) async {
    var callCount = 0;
    await pumpCard(tester, AgentCard(agent: _testAgent(), onCall: () => callCount++));

    await tester.tap(findKnife(KnifeIcon.phone));
    await tester.pump();

    expect(callCount, 1);
  });

  testWidgets('calls onWhatsApp callback when whatsapp button tapped', (tester) async {
    var waCount = 0;
    await pumpCard(tester, AgentCard(agent: _testAgent(), onWhatsApp: () => waCount++));

    await tester.tap(findKnife(KnifeIcon.chat));
    await tester.pump();

    expect(waCount, 1);
  });

  testWidgets('does not crash when onCall and onWhatsApp are null', (tester) async {
    await pumpCard(tester, AgentCard(agent: _testAgent()));

    // Tapping should not throw even with null callbacks (defaults to no-op).
    await tester.tap(findKnife(KnifeIcon.phone));
    await tester.pump();
    await tester.tap(findKnife(KnifeIcon.chat));
    await tester.pump();

    // No exception thrown means the test passes.
  });

  testWidgets('shows person icon placeholder when avatarUrl is null', (tester) async {
    await pumpCard(tester, AgentCard(agent: _testAgent(avatarUrl: null)));

    expect(findKnife(KnifeIcon.user), findsOneWidget);
  });

  testWidgets('renders beginner experience level', (tester) async {
    await pumpCard(tester, AgentCard(agent: _testAgent(experienceLevel: ExperienceLevel.beginner)));

    expect(find.textContaining('Beginner', findRichText: true), findsOneWidget);
  });

  testWidgets('renders intermediate experience level', (tester) async {
    await pumpCard(
      tester,
      AgentCard(agent: _testAgent(experienceLevel: ExperienceLevel.intermediate)),
    );

    expect(find.textContaining('Intermediate', findRichText: true), findsOneWidget);
  });

  testWidgets('shows no experience level for a value the app does not know', (tester) async {
    await pumpCard(tester, AgentCard(agent: _testAgent(experienceLevel: null)));

    expect(find.textContaining('Unknown', findRichText: true), findsNothing);
    expect(find.textContaining('Beginner', findRichText: true), findsNothing);
  });
}
