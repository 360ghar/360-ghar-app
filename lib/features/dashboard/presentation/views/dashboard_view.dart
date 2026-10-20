import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:ghar360/core/widgets/navigation/bottom_nav_bar.dart';

/// Each branch owns its navigation stack and retained view state. Inactive
/// branch tickers are disabled by StatefulShellRoute.indexedStack.
/// From [kRailBreakpoint] the destinations move to a rail on the left.
class DashboardView extends StatelessWidget {
  const DashboardView({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  void _go(int index) => navigationShell.goBranch(index);

  @override
  Widget build(BuildContext context) {
    final body = Semantics(identifier: 'qa.dashboard.indexed_stack', child: navigationShell);
    if (MediaQuery.sizeOf(context).width >= kRailBreakpoint) {
      return Scaffold(
        key: const ValueKey('qa.dashboard.screen'),
        body: Row(
          children: [
            PaperNavigationRail(currentIndex: navigationShell.currentIndex, onTap: _go),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      key: const ValueKey('qa.dashboard.screen'),
      // Discover's paper city runs on behind the roofline, so the lawn never
      // stops at a hard edge above the bar. Discover keeps its content in a
      // SafeArea; the other tabs end above the bar.
      extendBody: navigationShell.currentIndex == 0,
      body: body,
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _go,
      ),
    );
  }
}
