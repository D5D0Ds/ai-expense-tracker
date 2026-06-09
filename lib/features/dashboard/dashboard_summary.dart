import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:flutter/material.dart';

/// Monthly dashboard data prepared for the dashboard view.
final class DashboardSummary {
  /// Creates a dashboard summary.
  const DashboardSummary({
    required this.month,
    required this.monthExpenses,
    required this.spendEntries,
    required this.categoryTotals,
    required this.rankedSources,
    required this.totalSpend,
    required this.totalLent,
    required this.totalBorrowed,
    required this.averageDailySpend,
  });

  /// Month being summarized.
  final DateTime month;

  /// All entries in [month].
  final List<Expense> monthExpenses;

  /// Entries that count as ordinary spend.
  final List<Expense> spendEntries;

  /// Spend totals grouped by category.
  final Map<ExpenseCategory, double> categoryTotals;

  /// Spend totals grouped by source, highest first.
  final List<MapEntry<String, double>> rankedSources;

  /// Total ordinary spend.
  final double totalSpend;

  /// Total lent out.
  final double totalLent;

  /// Total borrowed.
  final double totalBorrowed;

  /// Average ordinary spend per elapsed day of [month].
  final double averageDailySpend;
}

/// Budget progress state for the dashboard hero.
final class BudgetProgress {
  /// Creates budget progress.
  const BudgetProgress({
    required this.percent,
    required this.isOver,
    required this.difference,
    required this.color,
  });

  /// Filled progress from zero to one.
  final double percent;

  /// Whether spend exceeds budget.
  final bool isOver;

  /// Absolute difference between spend and budget.
  final double difference;

  /// Presentation color for the current progress level.
  final Color color;
}

/// Builds dashboard summary data from confirmed expenses.
DashboardSummary computeDashboardSummary({
  required List<Expense> expenses,
  required DateTime month,
  required int elapsedDays,
}) {
  final monthExpenses = expenses
      .where(
        (expense) =>
            expense.occurredAt.year == month.year &&
            expense.occurredAt.month == month.month,
      )
      .toList();
  final spendEntries = monthExpenses
      .where((expense) => expense.transactionKind == TransactionKind.expense)
      .toList();
  final categoryTotals = <ExpenseCategory, double>{};
  final sourceBreakdown = <String, double>{};
  var totalSpend = 0.0;
  var totalLent = 0.0;
  var totalBorrowed = 0.0;

  for (final expense in monthExpenses) {
    switch (expense.transactionKind) {
      case TransactionKind.expense:
        totalSpend += expense.amount;
        categoryTotals.update(
          expense.category,
          (value) => value + expense.amount,
          ifAbsent: () => expense.amount,
        );
        sourceBreakdown.update(
          expenseSourceLabel(expense),
          (value) => value + expense.amount,
          ifAbsent: () => expense.amount,
        );
      case TransactionKind.income:
        break;
      case TransactionKind.lent:
        totalLent += expense.amount;
      case TransactionKind.borrowed:
        totalBorrowed += expense.amount;
    }
  }

  final rankedSources = sourceBreakdown.entries.toList()
    ..sort((left, right) => right.value.compareTo(left.value));
  final safeElapsedDays = elapsedDays <= 0 ? 1 : elapsedDays;

  return DashboardSummary(
    month: month,
    monthExpenses: monthExpenses,
    spendEntries: spendEntries,
    categoryTotals: categoryTotals,
    rankedSources: rankedSources,
    totalSpend: totalSpend,
    totalLent: totalLent,
    totalBorrowed: totalBorrowed,
    averageDailySpend: totalSpend / safeElapsedDays,
  );
}

/// Returns the display label for an expense source.
String expenseSourceLabel(Expense expense) {
  return expense.fundingSourceLabel ??
      expense.sourceLabel ??
      expense.paymentMethod.label;
}

/// Computes budget progress presentation values.
BudgetProgress computeBudgetProgress({
  required double totalSpend,
  required double budget,
  required Color safeColor,
  required Color warningColor,
  required Color dangerColor,
}) {
  final ratio = budget <= 0 ? 0.0 : totalSpend / budget;
  final color = budget <= 0 || ratio <= 0.75
      ? safeColor
      : ratio <= 1.0
      ? warningColor
      : dangerColor;

  return BudgetProgress(
    percent: ratio.clamp(0.0, 1.0),
    isOver: totalSpend > budget,
    difference: (totalSpend - budget).abs(),
    color: color,
  );
}
