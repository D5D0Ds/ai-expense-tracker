import 'package:ai_expense_tracker/features/reports/report_trend_data.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrendFilter', () {
    test('copyWith copies fields or overrides with null', () {
      final initial = TrendFilter(
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 30),
        category: ExpenseCategory.food,
        paymentMethod: PaymentMethodKind.upi,
        transactionKind: TransactionKind.expense,
        account: 'HDFC',
      );

      // 1. Copy with new values
      final updated = initial.copyWith(
        startDate: DateTime(2026, 6, 2),
        endDate: DateTime(2026, 6, 29),
        category: ExpenseCategory.shopping,
        paymentMethod: PaymentMethodKind.cash,
        transactionKind: TransactionKind.lent,
        account: 'Cash Account',
      );

      expect(updated.startDate, DateTime(2026, 6, 2));
      expect(updated.endDate, DateTime(2026, 6, 29));
      expect(updated.category, ExpenseCategory.shopping);
      expect(updated.paymentMethod, PaymentMethodKind.cash);
      expect(updated.transactionKind, TransactionKind.lent);
      expect(updated.account, 'Cash Account');

      // 2. Override with nulls
      final cleared = initial.copyWith(
        category: null,
        paymentMethod: null,
        transactionKind: null,
        account: null,
      );

      expect(cleared.startDate, initial.startDate);
      expect(cleared.endDate, initial.endDate);
      expect(cleared.category, isNull);
      expect(cleared.paymentMethod, isNull);
      expect(cleared.transactionKind, isNull);
      expect(cleared.account, isNull);

      // 3. No overrides keeps original fields
      final unchanged = initial.copyWith();
      expect(unchanged.startDate, initial.startDate);
      expect(unchanged.endDate, initial.endDate);
      expect(unchanged.category, initial.category);
      expect(unchanged.paymentMethod, initial.paymentMethod);
      expect(unchanged.transactionKind, initial.transactionKind);
      expect(unchanged.account, initial.account);
    });
  });

  group('computeTrendData', () {
    test('filters by date window and aggregates expense totals', () {
      // Arrange
      final expenses = [
        _expense(
          id: 'food',
          amount: 120,
          occurredAt: DateTime(2026, 6, 1),
          category: ExpenseCategory.food,
          paymentMethod: PaymentMethodKind.upi,
          sourceLabel: 'HDFC UPI',
        ),
        _expense(
          id: 'travel',
          amount: 300,
          occurredAt: DateTime(2026, 6, 10),
          category: ExpenseCategory.travel,
          paymentMethod: PaymentMethodKind.creditCard,
          fundingSourceLabel: 'Amex Gold',
        ),
        _expense(
          id: 'outside',
          amount: 500,
          occurredAt: DateTime(2026, 7, 1),
          category: ExpenseCategory.shopping,
        ),
      ];
      final filter = TrendFilter(
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 30),
      );

      // Act
      final trend = computeTrendData(expenses, filter);

      // Assert
      expect(trend.filteredExpenses.map((expense) => expense.id), [
        'food',
        'travel',
      ]);
      expect(trend.totalSpend, 420);
      expect(trend.monthlyTotals, {DateTime(2026, 6): 420.0});
      expect(trend.categoryTotals, {
        ExpenseCategory.food: 120.0,
        ExpenseCategory.travel: 300.0,
      });
      expect(trend.paymentMethodTotals, {
        PaymentMethodKind.upi: 120.0,
        PaymentMethodKind.creditCard: 300.0,
      });
      expect(trend.accountTotals, {
        'HDFC UPI': 120.0,
        'Amex Gold': 300.0,
      });
    });

    test('filters by category payment method transaction kind and account', () {
      // Arrange
      final expenses = [
        _expense(
          id: 'match',
          amount: 100,
          occurredAt: DateTime(2026, 6, 5),
          category: ExpenseCategory.food,
          paymentMethod: PaymentMethodKind.upi,
          sourceLabel: 'Primary UPI',
        ),
        _expense(
          id: 'category-miss',
          amount: 200,
          occurredAt: DateTime(2026, 6, 5),
          category: ExpenseCategory.travel,
          paymentMethod: PaymentMethodKind.upi,
          sourceLabel: 'Primary UPI',
        ),
        _expense(
          id: 'account-miss',
          amount: 300,
          occurredAt: DateTime(2026, 6, 5),
          category: ExpenseCategory.food,
          paymentMethod: PaymentMethodKind.upi,
          sourceLabel: 'Cash',
        ),
      ];
      final filter = TrendFilter(
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 30),
        category: ExpenseCategory.food,
        paymentMethod: PaymentMethodKind.upi,
        transactionKind: TransactionKind.expense,
        account: 'primary',
      );

      // Act
      final trend = computeTrendData(expenses, filter);

      // Assert
      expect(trend.filteredExpenses.single.id, 'match');
      expect(trend.totalSpend, 100);
    });

    test('tracks lent and borrowed totals without expense chart totals', () {
      // Arrange
      final expenses = [
        _expense(
          id: 'lent',
          amount: 80,
          occurredAt: DateTime(2026, 6, 3),
          transactionKind: TransactionKind.lent,
        ),
        _expense(
          id: 'borrowed',
          amount: 50,
          occurredAt: DateTime(2026, 6, 4),
          transactionKind: TransactionKind.borrowed,
        ),
      ];
      final filter = TrendFilter(
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 30),
      );

      // Act
      final trend = computeTrendData(expenses, filter);

      // Assert
      expect(trend.totalSpend, 0);
      expect(trend.totalLent, 80);
      expect(trend.totalBorrowed, 50);
      expect(trend.monthlyTotals, isEmpty);
      expect(trend.categoryTotals, isEmpty);
      expect(trend.paymentMethodTotals, isEmpty);
      expect(trend.accountTotals, isEmpty);
    });
  });
}

Expense _expense({
  required String id,
  required double amount,
  required DateTime occurredAt,
  ExpenseCategory category = ExpenseCategory.other,
  PaymentMethodKind paymentMethod = PaymentMethodKind.cash,
  TransactionKind transactionKind = TransactionKind.expense,
  String? sourceLabel,
  String? fundingSourceLabel,
}) {
  return Expense(
    id: id,
    amount: amount,
    currency: 'INR',
    occurredAt: occurredAt,
    payee: 'Payee',
    category: category,
    source: ExpenseSource.manual,
    transactionKind: transactionKind,
    paymentMethod: paymentMethod,
    sourceLabel: sourceLabel,
    fundingSourceLabel: fundingSourceLabel,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );
}
