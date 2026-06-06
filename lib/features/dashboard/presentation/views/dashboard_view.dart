import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/widgets/navigation/bottom_nav_bar.dart';
import 'package:ghar360/features/assistant/presentation/views/assistant_view.dart';
import 'package:ghar360/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:ghar360/features/discover/presentation/views/discover_view.dart';
import 'package:ghar360/features/explore/presentation/views/explore_view.dart';
import 'package:ghar360/features/likes/presentation/views/likes_view.dart';
import 'package:ghar360/features/profile/presentation/views/profile_view.dart';
import 'package:ghar360/features/visits/presentation/views/visits_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final controller = Get.find<DashboardController>();
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 3)) {
          SystemNavigator.pop();
        } else {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        key: const ValueKey('qa.dashboard.screen'),
        body: ObxValue<RxInt>(
          (idx) => Semantics(
            label: 'qa.dashboard.indexed_stack',
            identifier: 'qa.dashboard.indexed_stack',
            child: IndexedStack(
              index: idx.value,
              children: const [
                ProfileView(),
                ExploreView(),
                DiscoverView(),
                LikesView(),
                VisitsView(),
                AssistantView(),
              ],
            ),
          ),
          controller.currentIndex,
        ),
        bottomNavigationBar: ObxValue<RxInt>(
          (idx) => CustomBottomNavigationBar(currentIndex: idx.value, onTap: controller.changeTab),
          controller.currentIndex,
        ),
      ),
    );
  }
}
