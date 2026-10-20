import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/features/dashboard/presentation/views/dashboard_view.dart';

const shellPaths = ['/discover', '/explore', '/likes', '/visits', '/profile'];
const shellIds = ['discover', 'explore_properties', 'saved', 'visits', 'profile'];

GoRouter shellRouter({String initial = '/discover', Set<String>? built, Set<String>? disposed}) =>
    GoRouter(
      initialLocation: initial,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => DashboardView(navigationShell: shell),
          branches: [
            for (final path in shellPaths)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: path,
                    builder: (_, _) => _Branch(path: path, built: built, disposed: disposed),
                    routes: [
                      GoRoute(
                        path: 'detail',
                        builder: (_, _) => Scaffold(appBar: AppBar(title: Text('$path detail'))),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
        GoRoute(
          path: '/assistant',
          builder: (_, _) => Scaffold(appBar: AppBar(title: const Text('Assistant page'))),
        ),
      ],
    );

Widget shellApp(
  GoRouter router, {
  bool dark = false,
  double scale = 1,
  Locale locale = const Locale('en', 'US'),
}) => MaterialApp.router(
  routerConfig: router,
  theme: dark ? AppDesignTheme.dark() : AppDesignTheme.light(),
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
);

class _Branch extends StatefulWidget {
  const _Branch({required this.path, this.built, this.disposed});
  final String path;
  final Set<String>? built;
  final Set<String>? disposed;
  @override
  State<_Branch> createState() => _BranchState();
}

class _BranchState extends State<_Branch> {
  final input = TextEditingController();
  @override
  void initState() {
    super.initState();
    widget.built?.add(widget.path);
  }

  @override
  void dispose() {
    widget.disposed?.add(widget.path);
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      children: [
        Text(widget.path),
        TextField(key: ValueKey('${widget.path}.input'), controller: input),
        TextButton(
          onPressed: () => context.push('${widget.path}/detail'),
          child: const Text('Open detail'),
        ),
        TextButton(
          onPressed: () => context.push('/assistant'),
          child: const Text('Open Assistant'),
        ),
        for (var index = 0; index < 60; index++)
          ListTile(title: Text('${widget.path} item $index')),
      ],
    ),
  );
}

/// Phone width, so the shell shows the bottom strip instead of the rail.
void usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
