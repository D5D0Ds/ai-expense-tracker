import 'package:ai_expense_tracker/features/settings/budget_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier provider for managing monthly budgets historically.
final budgetControllerProvider =
    NotifierProvider<BudgetController, Map<String, double>>(
      BudgetController.new,
    );

/// Controller to store and fetch budgets with monthly historical fallback logic.
final class BudgetController extends Notifier<Map<String, double>> {
  /// Standard fallback budget if nothing has ever been configured.
  static const double defaultBudget = 40000;

  @override
  Map<String, double> build() {
    return ref.watch(budgetRepositoryProvider).loadAll();
  }

  /// Sets the budget for the specified month.
  /// [monthKey] is in 'YYYY-MM' format.
  Future<void> setBudget(String monthKey, double amount) async {
    final updated = Map<String, double>.from(state);
    updated[monthKey] = amount;
    state = updated;
    await ref.read(budgetRepositoryProvider).saveAll(updated);
  }

  /// Sets the budget for the month containing [date].
  Future<void> setBudgetForMonth(DateTime date, double amount) async {
    await setBudget(getMonthKey(date), amount);
  }

  /// Helper to get the month key as a String ('YYYY-MM') from a DateTime.
  String getMonthKey(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  /// Returns the budget for any given month, applying the fallback default.
  /// If an exact budget entry is found for that month, it returns it.
  /// Otherwise, it searches for the chronologically closest past month budget.
  /// If no past budget was ever set, it falls back to the chronologically oldest budget,
  /// and finally to the default budget of 40,000.
  double getBudgetForMonth(DateTime date) {
    return BudgetPolicy.resolveBudgetForMonth(
      budgets: state,
      monthKey: getMonthKey(date),
      defaultBudget: defaultBudget,
    );
  }
}

/// Pure budget lookup rules used by the settings ViewModel.
final class BudgetPolicy {
  const BudgetPolicy._();

  /// Returns the configured budget for [monthKey], applying fallback rules.
  static double resolveBudgetForMonth({
    required Map<String, double> budgets,
    required String monthKey,
    required double defaultBudget,
  }) {
    final exactBudget = budgets[monthKey];
    if (exactBudget != null) return exactBudget;

    final sortedKeys = budgets.keys.toList()..sort();
    final closestPastKey = sortedKeys.reversed
        .where((key) => key.compareTo(monthKey) <= 0)
        .firstOrNull;
    if (closestPastKey != null) return budgets[closestPastKey]!;

    if (sortedKeys.isNotEmpty) return budgets[sortedKeys.first]!;

    return defaultBudget;
  }
}
