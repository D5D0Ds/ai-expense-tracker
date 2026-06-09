import 'package:ai_expense_tracker/app/shell.dart';
import 'package:ai_expense_tracker/features/dashboard/dashboard_screen.dart';
import 'package:ai_expense_tracker/features/expenses/expense_detail_screen.dart';
import 'package:ai_expense_tracker/features/expenses/expense_list_screen.dart';
import 'package:ai_expense_tracker/features/model_asset/model_download_screen.dart';
import 'package:ai_expense_tracker/features/reports/reports_screen.dart';
import 'package:ai_expense_tracker/features/settings/settings_screen.dart';
import 'package:ai_expense_tracker/features/sms_suggestions/sms_suggestions_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Provides app navigation.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/expenses',
                builder: (context, state) => const ExpenseListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ExpenseDetailScreen(
                      id: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/sms',
        builder: (context, state) => const SmsSuggestionsScreen(),
      ),
      GoRoute(
        path: '/model',
        builder: (context, state) => const ModelDownloadScreen(),
      ),
    ],
  );
});
