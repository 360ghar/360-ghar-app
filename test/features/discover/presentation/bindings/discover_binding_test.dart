import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/discover/presentation/controllers/discover_controller.dart';
import '../../../../helpers/property_query_test_support.dart';

void main() {
  test('Discover session is owned by its ProviderContainer and clears on disposal', () async {
    final first = await PropertyQueryHarness.create();
    final second = await PropertyQueryHarness.create();
    addTearDown(first.close);
    addTearDown(second.close);
    expect(first.container.read(discoverProvider).total, 0);
    expect(
      identical(
        first.container.read(discoverProvider.notifier),
        second.container.read(discoverProvider.notifier),
      ),
      isFalse,
    );
    first.disposeProviders();
    expect(second.container.read(discoverProvider).total, 0);
  });
}
