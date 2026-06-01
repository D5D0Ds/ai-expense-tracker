import 'package:ai_expense_tracker/app/router.dart';
import 'package:ai_expense_tracker/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Root app widget.
class ExpenseTrackerApp extends ConsumerWidget {
  /// Creates the app.
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ShadApp.router(
      title: 'AI Expense Tracker',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(appRouterProvider),
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark,
      theme: AppTheme.dark,
      backgroundColor: AppTheme.background,
    );
  }
}
