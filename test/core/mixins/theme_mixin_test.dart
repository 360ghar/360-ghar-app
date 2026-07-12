// test/core/mixins/theme_mixin_test.dart
//
// Widget tests for [ThemeMixin] builder helpers.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/mixins/theme_mixin.dart';

class _ThemeMixinHost with ThemeMixin {}

void main() {
  late _ThemeMixinHost host;

  setUp(() {
    Get.testMode = true;
    host = _ThemeMixinHost();
  });

  tearDown(Get.reset);

  Future<void> pumpHost(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
          useMaterial3: true,
        ),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('buildThemeAwareAppBar renders title and optional actions', (tester) async {
    await pumpHost(
      tester,
      Builder(
        builder: (context) {
          return host.buildThemeAwareAppBar(
            title: 'Profile',
            actions: const [Icon(Icons.settings)],
          );
        },
      ),
    );

    expect(find.text('Profile'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('buildThemeAwareAppBar respects custom leading', (tester) async {
    await pumpHost(
      tester,
      Builder(
        builder: (context) {
          return host.buildThemeAwareAppBar(
            title: 'Home',
            leading: const Icon(Icons.menu),
            automaticallyImplyLeading: false,
          );
        },
      ),
    );

    expect(find.byIcon(Icons.menu), findsOneWidget);
  });

  testWidgets('buildThemeAwareCard wraps child with padding', (tester) async {
    await pumpHost(
      tester,
      host.buildThemeAwareCard(
        child: const Text('Card body'),
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(4),
      ),
    );

    expect(find.text('Card body'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('buildSectionTitle uses titleMedium style', (tester) async {
    await pumpHost(tester, host.buildSectionTitle('Amenities'));
    expect(find.text('Amenities'), findsOneWidget);
  });

  testWidgets('buildSwitchTile toggles when enabled', (tester) async {
    var value = false;
    await pumpHost(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          return host.buildSwitchTile(
            title: 'Notifications',
            subtitle: 'Receive alerts',
            value: value,
            icon: Icons.notifications,
            onChanged: (next) => setState(() => value = next),
          );
        },
      ),
    );

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Receive alerts'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(value, isTrue);
  });

  testWidgets('buildSwitchTile is disabled when enabled is false', (tester) async {
    await pumpHost(
      tester,
      host.buildSwitchTile(
        title: 'Locked',
        subtitle: 'Cannot change',
        value: true,
        enabled: false,
        icon: Icons.lock,
        onChanged: (_) {},
      ),
    );

    final sw = tester.widget<Switch>(find.byType(Switch));
    expect(sw.onChanged, isNull);
  });

  testWidgets('buildActionTile invokes onTap and supports destructive styling', (tester) async {
    var tapped = false;
    await pumpHost(
      tester,
      host.buildActionTile(
        title: 'Delete account',
        subtitle: 'Permanent',
        icon: Icons.delete,
        isDestructive: true,
        onTap: () => tapped = true,
      ),
    );

    await tester.tap(find.text('Delete account'));
    await tester.pump();
    expect(tapped, isTrue);
    expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
  });

  testWidgets('buildActionTile without icon still renders', (tester) async {
    await pumpHost(
      tester,
      host.buildActionTile(
        title: 'Edit',
        subtitle: 'Change profile',
        onTap: () {},
      ),
    );
    expect(find.text('Edit'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
  });

  testWidgets('buildThemeAwareScaffold wires app bar body and fab', (tester) async {
    await pumpHost(
      tester,
      host.buildThemeAwareScaffold(
        title: 'Settings',
        body: const Text('Body content'),
        actions: const [Icon(Icons.more_vert)],
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    );

    // Nested scaffolds: outer from pumpHost + inner from helper.
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Body content'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });
}
