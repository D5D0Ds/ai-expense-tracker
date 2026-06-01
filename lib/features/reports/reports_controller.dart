import 'dart:io';

import 'package:ai_expense_tracker/features/expenses/expense_api.dart';
import 'package:ai_expense_tracker/features/reports/report_export_service.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Trend analyzer filter notifier.
final class TrendFilterNotifier extends Notifier<TrendFilter> {
  @override
  TrendFilter build() {
    final now = ref.watch(nowProvider)();
    return TrendFilter(
      startDate: DateTime(now.year, now.month - 5, 1),
      endDate: DateTime(
        now.year,
        now.month + 1,
        1,
      ).subtract(const Duration(days: 1)),
    );
  }

  /// Current filter value.
  TrendFilter get filter => state;

  /// Replaces the current filter.
  set filter(TrendFilter value) => state = value;
}

/// Trend analyzer filter state.
final trendFilterProvider = NotifierProvider<TrendFilterNotifier, TrendFilter>(
  TrendFilterNotifier.new,
);

/// Current monthly report state.
final reportControllerProvider = AsyncNotifierProvider<ReportController, File?>(
  ReportController.new,
);

/// Controls monthly report exports.
final class ReportController extends AsyncNotifier<File?> {
  @override
  Future<File?> build() async => null;

  /// Exports current month to Excel and shares it.
  Future<void> exportExcel(DateTime month) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final expenses = _expensesForMonth(month);
      final file = await ref
          .read(reportExportServiceProvider)
          .exportExcel(
            expenses,
            month,
          );
      await ref.read(reportExportServiceProvider).share(file);
      await ref.read(expenseReloaderProvider).reload();
      return file;
    });
  }

  /// Exports current month to PDF and shares it.
  Future<void> exportPdf(DateTime month) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final expenses = _expensesForMonth(month);
      final file = await ref
          .read(reportExportServiceProvider)
          .exportPdf(
            expenses,
            month,
          );
      await ref.read(reportExportServiceProvider).share(file);
      await ref.read(expenseReloaderProvider).reload();
      return file;
    });
  }

  List<Expense> _expensesForMonth(DateTime month) {
    final expenses =
        ref.read(confirmedExpensesProvider).asData?.value ?? const <Expense>[];
    return expenses
        .where(
          (expense) =>
              expense.occurredAt.year == month.year &&
              expense.occurredAt.month == month.month,
        )
        .toList();
  }
}

/// Immutable filter for the trend analyzer.
final class TrendFilter {
  /// Creates a trend filter.
  const TrendFilter({
    required this.startDate,
    required this.endDate,
    this.category,
    this.paymentMethod,
    this.transactionKind,
    this.account,
  });

  /// Custom start date.
  final DateTime startDate;

  /// Custom end date.
  final DateTime endDate;

  /// Optional category filter.
  final ExpenseCategory? category;

  /// Optional payment method filter.
  final PaymentMethodKind? paymentMethod;

  /// Optional transaction kind filter.
  final TransactionKind? transactionKind;

  /// Optional account or card filter string.
  final String? account;

  static const _sentinel = Object();

  /// Returns a copy with changed fields.
  TrendFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    Object? category = _sentinel,
    Object? paymentMethod = _sentinel,
    Object? transactionKind = _sentinel,
    Object? account = _sentinel,
  }) {
    return TrendFilter(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      category: category == _sentinel
          ? this.category
          : (category as ExpenseCategory?),
      paymentMethod: paymentMethod == _sentinel
          ? this.paymentMethod
          : (paymentMethod as PaymentMethodKind?),
      transactionKind: transactionKind == _sentinel
          ? this.transactionKind
          : (transactionKind as TransactionKind?),
      account: account == _sentinel ? this.account : (account as String?),
    );
  }
}

/// A date window for trend queries.
final class TrendDateWindow {
  /// Creates a window.
  const TrendDateWindow(this.start, this.end);

  /// Inclusive start.
  final DateTime start;

  /// Inclusive end.
  final DateTime end;

  /// Whether a date falls within this window.
  bool contains(DateTime date) => !date.isBefore(start) && !date.isAfter(end);
}

/// Aggregated trend data for charting.
final class TrendData {
  /// Creates trend data.
  const TrendData({
    required this.monthlyTotals,
    required this.categoryTotals,
    required this.paymentMethodTotals,
    required this.accountTotals,
    required this.filteredExpenses,
    required this.totalSpend,
    required this.totalLent,
    required this.totalBorrowed,
    required this.dateWindow,
  });

  /// Month-keyed spend totals.
  final Map<DateTime, double> monthlyTotals;

  /// Category-keyed spend totals.
  final Map<ExpenseCategory, double> categoryTotals;

  /// Payment-method-keyed spend totals.
  final Map<PaymentMethodKind, double> paymentMethodTotals;

  /// Account-keyed spend totals.
  final Map<String, double> accountTotals;

  /// Expenses matching the current filter.
  final List<Expense> filteredExpenses;

  /// Total spend (expense kind only).
  final double totalSpend;

  /// Total lent.
  final double totalLent;

  /// Total borrowed.
  final double totalBorrowed;

  /// Date window used for aggregation.
  final TrendDateWindow dateWindow;
}

/// Computes trend data from the full expense list using the current filter.
TrendData computeTrendData(List<Expense> allExpenses, TrendFilter filter) {
  final window = TrendDateWindow(filter.startDate, filter.endDate);

  final filtered = allExpenses.where((e) {
    if (!window.contains(e.occurredAt)) return false;
    if (filter.category != null && e.category != filter.category) return false;
    if (filter.paymentMethod != null &&
        e.paymentMethod != filter.paymentMethod) {
      return false;
    }
    if (filter.transactionKind != null &&
        e.transactionKind != filter.transactionKind) {
      return false;
    }
    if (filter.account != null) {
      final label =
          e.fundingSourceLabel ?? e.sourceLabel ?? e.paymentMethod.label;
      if (!label.toLowerCase().contains(filter.account!.toLowerCase())) {
        return false;
      }
    }
    return true;
  }).toList();

  final monthlyTotals = <DateTime, double>{};
  final categoryTotals = <ExpenseCategory, double>{};
  final paymentMethodTotals = <PaymentMethodKind, double>{};
  final accountTotals = <String, double>{};

  var totalSpend = 0.0;
  var totalLent = 0.0;
  var totalBorrowed = 0.0;

  for (final expense in filtered) {
    switch (expense.transactionKind) {
      case TransactionKind.expense:
        totalSpend += expense.amount;
        final monthKey = DateTime(
          expense.occurredAt.year,
          expense.occurredAt.month,
        );
        monthlyTotals[monthKey] =
            (monthlyTotals[monthKey] ?? 0) + expense.amount;
        categoryTotals[expense.category] =
            (categoryTotals[expense.category] ?? 0) + expense.amount;
        paymentMethodTotals[expense.paymentMethod] =
            (paymentMethodTotals[expense.paymentMethod] ?? 0) + expense.amount;
        final accountKey =
            expense.fundingSourceLabel ??
            expense.sourceLabel ??
            expense.paymentMethod.label;
        accountTotals[accountKey] =
            (accountTotals[accountKey] ?? 0) + expense.amount;
      case TransactionKind.lent:
        totalLent += expense.amount;
      case TransactionKind.borrowed:
        totalBorrowed += expense.amount;
    }
  }

  return TrendData(
    monthlyTotals: monthlyTotals,
    categoryTotals: categoryTotals,
    paymentMethodTotals: paymentMethodTotals,
    accountTotals: accountTotals,
    filteredExpenses: filtered,
    totalSpend: totalSpend,
    totalLent: totalLent,
    totalBorrowed: totalBorrowed,
    dateWindow: window,
  );
}
