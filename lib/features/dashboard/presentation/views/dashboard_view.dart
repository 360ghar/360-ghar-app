import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/widgets/common/sign_in_gate.dart';
import 'package:ghar360/core/widgets/navigation/bottom_nav_bar.dart';
import 'package:go_router/go_router.dart';

/// Each branch owns its navigation stack and retained view state. Inactive
/// branch tickers are disabled by StatefulShellRoute.indexedStack.
/// From [kRailBreakpoint] the destinations move to a rail on the left.
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  /// Likes, Visits and Profile are account tabs: a guest gets the sign-in sheet
  /// and the branch stays where it is.
  Future<void> _go(BuildContext context, WidgetRef ref, int index) async {
    if (index >= 2 && !await requireAccount(context, ref)) return;
    navigationShell.goBranch(index);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void go(int index) => _go(context, ref, index);
    final body = Semantics(identifier: 'qa.dashboard.indexed_stack', child: navigationShell);
    if (MediaQuery.sizeOf(context).width >= kRailBreakpoint) {
      return Scaffold(
        key: const ValueKey('qa.dashboard.screen'),
        body: Row(
          children: [
            PaperNavigationRail(currentIndex: navigationShell.currentIndex, onTap: go),
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
        onTap: go,
      ),
    );
  }
}
