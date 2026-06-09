import 'package:ai_expense_tracker/features/expenses/expense_list_summary.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeExpenseListSummary', () {
    test('builds sorted unique source options', () {
      // Arrange
      final expenses = [
        _expense(id: 'a', sourceLabel: 'Card B'),
        _expense(id: 'b', sourceLabel: 'Card A', fundingSourceLabel: 'Bank C'),
        _expense(id: 'c', sourceLabel: 'Card A'),
      ];

      // Act
      final summary = computeExpenseListSummary(
        expenses: expenses,
        filter: const ExpenseListFilter(),
      );

      // Assert
      expect(summary.sourceOptions, ['Bank C', 'Card A', 'Card B']);
    });

    test('filters by query across searchable fields', () {
      // Arrange
      final expenses = [
        _expense(id: 'food', payee: 'Swiggy', category: ExpenseCategory.food),
        _expense(id: 'bank', fundingSourceLabel: 'Kotak Account'),
        _expense(id: 'travel', payee: 'Metro'),
      ];

      // Act
      final summary = computeExpenseListSummary(
        expenses: expenses,
        filter: const ExpenseListFilter(query: 'kotak'),
      );

      // Assert
      expect(summary.filteredExpenses.map((expense) => expense.id), ['bank']);
    });

    test('applies category, kind, method, and source filters together', () {
      // Arrange
      final expenses = [
        _expense(
          id: 'match',
          category: ExpenseCategory.food,
          transactionKind: TransactionKind.expense,
          paymentMethod: PaymentMethodKind.upi,
          sourceLabel: 'HDFC UPI',
        ),
        _expense(
          id: 'wrong-category',
          category: ExpenseCategory.travel,
          transactionKind: TransactionKind.expense,
          paymentMethod: PaymentMethodKind.upi,
          sourceLabel: 'HDFC UPI',
        ),
        _expense(
          id: 'wrong-kind',
          category: ExpenseCategory.food,
          transactionKind: TransactionKind.lent,
          paymentMethod: PaymentMethodKind.upi,
          sourceLabel: 'HDFC UPI',
        ),
      ];

      // Act
      final summary = computeExpenseListSummary(
        expenses: expenses,
        filter: const ExpenseListFilter(
          category: ExpenseCategory.food,
          transactionKind: TransactionKind.expense,
          paymentMethod: PaymentMethodKind.upi,
          sourceLabel: 'HDFC UPI',
        ),
      );

      // Assert
      expect(summary.filteredExpenses.map((expense) => expense.id), ['match']);
    });

    test('computes outgoing and borrowed totals from visible entries', () {
      // Arrange
      final expenses = [
        _expense(
          id: 'expense',
          amount: 100,
          transactionKind: TransactionKind.expense,
        ),
        _expense(
          id: 'lent',
          amount: 50,
          transactionKind: TransactionKind.lent,
        ),
        _expense(
          id: 'borrowed',
          amount: 75,
          transactionKind: TransactionKind.borrowed,
        ),
      ];

      // Act
      final summary = computeExpenseListSummary(
        expenses: expenses,
        filter: const ExpenseListFilter(),
      );

      // Assert: outgoingTotal counts only expenses, not loans given (lent).
      expect(summary.outgoingTotal, 100);
      expect(summary.borrowedTotal, 75);
    });
  });
}

Expense _expense({
  required String id,
  double amount = 100,
  String? payee,
  ExpenseCategory category = ExpenseCategory.other,
  TransactionKind transactionKind = TransactionKind.expense,
  PaymentMethodKind paymentMethod = PaymentMethodKind.upi,
  String? sourceLabel,
  String? fundingSourceLabel,
}) {
  return Expense(
    id: id,
    amount: amount,
    currency: 'INR',
    occurredAt: DateTime(2026),
    payee: payee ?? id,
    category: category,
    source: ExpenseSource.manual,
    transactionKind: transactionKind,
    paymentMethod: paymentMethod,
    sourceLabel: sourceLabel,
    fundingSourceLabel: fundingSourceLabel,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}
