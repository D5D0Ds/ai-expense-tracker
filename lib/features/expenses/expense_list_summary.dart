import 'package:ai_expense_tracker/shared/core/domain_models.dart';

/// User-selected filters for the expense ledger.
final class ExpenseListFilter {
  /// Creates an expense list filter.
  const ExpenseListFilter({
    this.query = '',
    this.category,
    this.transactionKind,
    this.paymentMethod,
    this.sourceLabel,
  });

  /// Free-text query.
  final String query;

  /// Optional category filter.
  final ExpenseCategory? category;

  /// Optional transaction type filter.
  final TransactionKind? transactionKind;

  /// Optional payment method filter.
  final PaymentMethodKind? paymentMethod;

  /// Optional source or funding label filter.
  final String? sourceLabel;
}

/// Prepared ledger data for the expense list view.
final class ExpenseListSummary {
  /// Creates an expense list summary.
  const ExpenseListSummary({
    required this.filteredExpenses,
    required this.sourceOptions,
    required this.outgoingTotal,
    required this.borrowedTotal,
  });

  /// Expenses matching the current filters.
  final List<Expense> filteredExpenses;

  /// Available source and funding labels.
  final List<String> sourceOptions;

  /// Visible outgoing total.
  final double outgoingTotal;

  /// Visible borrowed total.
  final double borrowedTotal;
}

/// Computes visible expenses, source options, and summary totals.
ExpenseListSummary computeExpenseListSummary({
  required List<Expense> expenses,
  required ExpenseListFilter filter,
}) {
  final normalizedQuery = filter.query.trim().toLowerCase();
  final sourceOptions = {
    for (final expense in expenses) ...[
      if (expense.sourceLabel != null) expense.sourceLabel!,
      if (expense.fundingSourceLabel != null) expense.fundingSourceLabel!,
    ],
  }.toList()..sort();

  final filteredExpenses = expenses.where((expense) {
    return _matchesQuery(expense, normalizedQuery) &&
        (filter.category == null || expense.category == filter.category) &&
        (filter.transactionKind == null ||
            expense.transactionKind == filter.transactionKind) &&
        (filter.paymentMethod == null ||
            expense.paymentMethod == filter.paymentMethod) &&
        (filter.sourceLabel == null ||
            expense.sourceLabel == filter.sourceLabel ||
            expense.fundingSourceLabel == filter.sourceLabel);
  }).toList();

  var outgoingTotal = 0.0;
  var borrowedTotal = 0.0;
  for (final expense in filteredExpenses) {
    if (expense.transactionKind == TransactionKind.borrowed) {
      borrowedTotal += expense.amount;
    }
    if (!expense.transactionKind.isIncoming) {
      outgoingTotal += expense.amount;
    }
  }

  return ExpenseListSummary(
    filteredExpenses: filteredExpenses,
    sourceOptions: sourceOptions,
    outgoingTotal: outgoingTotal,
    borrowedTotal: borrowedTotal,
  );
}

bool _matchesQuery(Expense expense, String query) {
  if (query.isEmpty) return true;
  return expense.payee.toLowerCase().contains(query) ||
      expense.category.label.toLowerCase().contains(query) ||
      expense.transactionKind.label.toLowerCase().contains(query) ||
      expense.paymentMethod.label.toLowerCase().contains(query) ||
      (expense.sourceLabel?.toLowerCase().contains(query) ?? false) ||
      (expense.fundingSourceLabel?.toLowerCase().contains(query) ?? false);
}
