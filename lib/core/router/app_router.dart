import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/accounts/account_detail_screen.dart';
import '../../features/accounts/accounts_screen.dart';
import '../../features/activity/activity_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/insights/category_insight_screen.dart';
import '../../features/insights/insights_screen.dart';
import '../../features/plan/budget_detail_screen.dart';
import '../../features/plan/goal_detail_screen.dart';
import '../../features/plan/plan_screen.dart';
import '../../features/plan/recurring_detail_screen.dart';
import '../../features/settings/about_screen.dart';
import '../../features/settings/appearance_screen.dart';
import '../../features/settings/backup_screen.dart';
import '../../features/settings/categories_screen.dart';
import '../../features/settings/currency_screen.dart';
import '../../features/settings/security_screen.dart';
import '../../features/settings/settings_screen.dart';
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
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                    routes: [
                      GoRoute(
                        path: 'categories',
                        builder: (context, state) => const CategoriesScreen(),
                      ),
                      GoRoute(
                        path: 'currency',
                        builder: (context, state) => const CurrencyScreen(),
                      ),
                      GoRoute(
                        path: 'appearance',
                        builder: (context, state) => const AppearanceScreen(),
                      ),
                      GoRoute(
                        path: 'security',
                        builder: (context, state) => const SecurityScreen(),
                      ),
                      GoRoute(
                        path: 'backup',
                        builder: (context, state) => const BackupScreen(),
                      ),
                      GoRoute(
                        path: 'about',
                        builder: (context, state) => const AboutScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'accounts',
                    builder: (context, state) => const AccountsScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => AccountDetailScreen(
                          id: int.parse(state.pathParameters['id']!),
                        ),
                      ),
                    ],
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
                routes: [
                  GoRoute(
                    path: 'budget/:id',
                    builder: (context, state) => BudgetDetailScreen(
                      id: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                  GoRoute(
                    path: 'goal/:id',
                    builder: (context, state) => GoalDetailScreen(
                      id: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                  GoRoute(
                    path: 'recurring/:id',
                    builder: (context, state) => RecurringDetailScreen(
                      id: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                  GoRoute(
                    path: 'entry/:id',
                    builder: (context, state) => EntryDetailScreen(
                      id: int.parse(state.pathParameters['id']!),
                      backLabel: AppLocalizations.of(context).tabPlan,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.insights,
                builder: (context, state) => const InsightsScreen(),
                routes: [
                  GoRoute(
                    path: 'category/:id',
                    builder: (context, state) => CategoryInsightScreen(
                      id: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                  GoRoute(
                    path: 'entry/:id',
                    builder: (context, state) => EntryDetailScreen(
                      id: int.parse(state.pathParameters['id']!),
                      backLabel: AppLocalizations.of(context).tabInsights,
                    ),
                  ),
                ],
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
