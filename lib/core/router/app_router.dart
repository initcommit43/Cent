import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/activity/activity_screen.dart';
import '../../features/activity/search_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/insights/insights_screen.dart';
import '../../features/plan/plan_screen.dart';
import '../../features/transactions/entry_detail_screen.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/cent_tab_bar.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _TabShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'entry/:id',
                    builder: (context, state) => EntryDetailScreen(
                      id: int.parse(state.pathParameters['id']!),
                      backLabel: AppLocalizations.of(context).tabHome,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.activity,
                builder: (context, state) => const ActivityScreen(),
                routes: [
                  GoRoute(
                    path: 'search',
                    builder: (context, state) => const SearchScreen(),
                  ),
                  GoRoute(
                    path: 'entry/:id',
                    builder: (context, state) => EntryDetailScreen(
                      id: int.parse(state.pathParameters['id']!),
                      backLabel: AppLocalizations.of(context).tabActivity,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.plan,
                builder: (context, state) => const PlanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.insights,
                builder: (context, state) => const InsightsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: CentTabBar(
        currentIndex: shell.currentIndex,
        items: [
          CentTabItem(icon: LucideIcons.house300, label: l10n.tabHome),
          CentTabItem(icon: LucideIcons.list300, label: l10n.tabActivity),
          CentTabItem(icon: LucideIcons.target300, label: l10n.tabPlan),
          CentTabItem(icon: LucideIcons.chartPie300, label: l10n.tabInsights),
        ],
        // Tapping the active tab returns that tab to its root, as on iOS.
        onTap: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
      ),
    );
  }
}
