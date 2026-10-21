// Profile uses Theme.of(context) and context.design directly; no GetX mixin.

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/widgets/paper/scene_header_sliver.dart';
import 'package:ghar360/features/profile/presentation/views/about_view.dart';
import 'package:ghar360/features/profile/presentation/views/edit_profile_view.dart';
import 'package:ghar360/features/profile/presentation/views/feedback_view.dart';
import 'package:ghar360/features/profile/presentation/views/help_view.dart';
import 'package:ghar360/features/profile/presentation/views/privacy_view.dart';
import 'package:ghar360/features/profile/presentation/views/profile_view.dart';
import '../../helpers/profile_test_harness.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('profile text follows the local $brightness theme', (tester) async {
      final h = ProfileHarness();
      addTearDown(h.close);
      await h.pump(tester, const ProfileView(), brightness: brightness);
      final name = find.text('Test User');
      final context = tester.element(name);
      expect(Theme.of(context).brightness, brightness);
      expect(tester.widget<Text>(name).style?.color, Theme.of(context).colorScheme.onSurface);
      expect(find.byType(SceneHeaderSliver), findsOneWidget);
    });
    for (final view in <Widget>[
      const ProfileView(),
      const EditProfileView(),
      const FeedbackView(),
      const HelpView(),
      const AboutView(),
      const PrivacyView(),
    ]) {
      testWidgets('${view.runtimeType} fits 320px and large text in $brightness', (tester) async {
        final h = ProfileHarness();
        addTearDown(h.close);
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await h.pump(tester, view, brightness: brightness, scale: 2);
        await tester.pump();
        expect(tester.takeException(), isNull);
        final scroll = find.byType(Scrollable).first;
        for (var i = 0; i < 6; i++) {
          await tester.drag(scroll, const Offset(0, -500));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
