import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/likes_segment.dart';
import 'package:ghar360/features/likes/presentation/controllers/likes_controller.dart';
import '../../../../helpers/property_query_test_support.dart';

void main() {
  test('Saved selection is isolated by provider scope', () async {
    final first = await PropertyQueryHarness.create();
    final second = await PropertyQueryHarness.create();
    addTearDown(first.close);
    addTearDown(second.close);
    first.container.read(likesProvider.notifier).switchToSegment(LikesSegment.passed);
    expect(first.container.read(likesProvider), LikesSegment.passed);
    expect(second.container.read(likesProvider), LikesSegment.liked);
  });
}
