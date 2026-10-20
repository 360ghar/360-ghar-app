import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/tools/presentation/controllers/emi_calculator_controller.dart';

void main() {
  test('calculator state is isolated between provider scopes', () {
    final first = ProviderContainer();
    final second = ProviderContainer();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    first.read(emiCalculatorProvider.notifier).updateInputs(principal: '1000');
    expect(first.read(emiCalculatorProvider).principal, '1000');
    expect(second.read(emiCalculatorProvider).principal, isEmpty);
  });

  test('calculator state is released after its final listener leaves', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final listener = container.listen(emiCalculatorProvider, (_, _) {});
    container.read(emiCalculatorProvider.notifier).updateInputs(principal: '1000');
    listener.close();
    await container.pump();
    expect(container.exists(emiCalculatorProvider), isFalse);
    expect(container.read(emiCalculatorProvider).principal, isEmpty);
  });
}
