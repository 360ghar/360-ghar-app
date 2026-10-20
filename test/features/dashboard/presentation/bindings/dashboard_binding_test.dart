// Route branches replace eager dependency registration.

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/dashboard_shell_app.dart';

void main() {
  testWidgets('creates branches lazily and disposes their local resources with the shell', (
    tester,
  ) async {
    final built = <String>{};
    final disposed = <String>{};
    final router = shellRouter(built: built, disposed: disposed);
    addTearDown(router.dispose);
    await tester.pumpWidget(shellApp(router));
    await tester.pumpAndSettle();
    expect(built, {'/discover'});
    for (var i = 0; i < shellPaths.length; i++) {
      await tester.tap(find.byKey(ValueKey('qa.dashboard.nav.${shellIds[i]}')));
      await tester.pumpAndSettle();
    }
    expect(built, shellPaths.toSet());
    expect(disposed, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(disposed, shellPaths.toSet());
    expect(tester.takeException(), isNull);
  });
}
