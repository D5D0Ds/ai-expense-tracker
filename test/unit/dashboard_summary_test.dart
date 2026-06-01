import 'package:ai_expense_tracker/features/dashboard/dashboard_summary.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeDashboardSummary', () {
    test('summarizes only the selected month', () {
      // Arrange
      final month = DateTime(2026, 6);
      final expenses = [
        _expense(
          id: 'food',
          amount: 100,
          occurredAt: DateTime(2026, 6, 2),
          category: ExpenseCategory.food,
          sourceLabel: 'Card A',
        ),
        _expense(
          id: 'travel',
          amount: 250,
          occurredAt: DateTime(2026, 6, 3),
          category: ExpenseCategory.travel,
          fundingSourceLabel: 'Bank B',
        ),
        _expense(
          id: 'lent',
          amount: 50,
          occurredAt: DateTime(2026, 6, 4),
          category: ExpenseCategory.transfer,
          transactionKind: TransactionKind.lent,
        ),
        _expense(
          id: 'borrowed',
          amount: 75,
          occurredAt: DateTime(2026, 6, 5),
          category: ExpenseCategory.transfer,
          transactionKind: TransactionKind.borrowed,
        ),
        _expense(
          id: 'previous-month',
          amount: 1000,
          occurredAt: DateTime(2026, 5, 31),
          category: ExpenseCategory.shopping,
        ),
      ];

      // Act
      final summary = computeDashboardSummary(
        expenses: expenses,
        month: month,
        elapsedDays: 5,
      );

      // Assert
      expect(summary.monthExpenses.map((expense) => expense.id), [
        'food',
        'travel',
        'lent',
        'borrowed',
      ]);
      expect(summary.spendEntries.map((expense) => expense.id), [
        'food',
        'travel',
      ]);
      expect(summary.totalSpend, 350);
      expect(summary.totalLent, 50);
      expect(summary.totalBorrowed, 75);
      expect(summary.averageDailySpend, 70);
      expect(summary.categoryTotals[ExpenseCategory.food], 100);
      expect(summary.categoryTotals[ExpenseCategory.travel], 250);
      expect(summary.rankedSources.first.key, 'Bank B');
      expect(summary.rankedSources.first.value, 250);
      expect(summary.rankedSources.last.key, 'Card A');
    });

    test('uses one day for average when elapsed days is invalid', () {
      // Arrange
      final expenses = [
        _expense(
          id: 'food',
          amount: 100,
          occurredAt: DateTime(2026, 6, 2),
          category: ExpenseCategory.food,
        ),
      ];

      // Act
      final summary = computeDashboardSummary(
        expenses: expenses,
        month: DateTime(2026, 6),
        elapsedDays: 0,
      );

      // Assert
      expect(summary.averageDailySpend, 100);
    });
  });

  group('computeBudgetProgress', () {
    test('uses safe color at or below seventy five percent', () {
      // Arrange
      const safe = Color(0xFF00FF00);
      const warning = Color(0xFFFFFF00);
      const danger = Color(0xFFFF0000);

      // Act
      final progress = computeBudgetProgress(
        totalSpend: 75,
        budget: 100,
        safeColor: safe,
        warningColor: warning,
        dangerColor: danger,
      );

      // Assert
      expect(progress.percent, 0.75);
      expect(progress.isOver, isFalse);
      expect(progress.difference, 25);
      expect(progress.color, safe);
    });

    test('uses warning color above seventy five percent up to budget', () {
      // Arrange
      const safe = Color(0xFF00FF00);
      const warning = Color(0xFFFFFF00);
      const danger = Color(0xFFFF0000);

      // Act
      final progress = computeBudgetProgress(
        totalSpend: 90,
        budget: 100,
        safeColor: safe,
        warningColor: warning,
        dangerColor: danger,
      );

      // Assert
      expect(progress.percent, 0.9);
      expect(progress.isOver, isFalse);
      expect(progress.difference, 10);
      expect(progress.color, warning);
    });

    test('caps percent and uses danger color over budget', () {
      // Arrange
      const safe = Color(0xFF00FF00);
      const warning = Color(0xFFFFFF00);
      const danger = Color(0xFFFF0000);

      // Act
      final progress = computeBudgetProgress(
        totalSpend: 125,
        budget: 100,
        safeColor: safe,
        warningColor: warning,
        dangerColor: danger,
      );

      // Assert
      expect(progress.percent, 1);
      expect(progress.isOver, isTrue);
      expect(progress.difference, 25);
      expect(progress.color, danger);
    });
  });
}

Expense _expense({
  required String id,
  required double amount,
  required DateTime occurredAt,
  required ExpenseCategory category,
  TransactionKind transactionKind = TransactionKind.expense,
  String? sourceLabel,
  String? fundingSourceLabel,
}) {
  return Expense(
    id: id,
    amount: amount,
    currency: 'INR',
    occurredAt: occurredAt,
    payee: id,
    category: category,
    source: ExpenseSource.manual,
    transactionKind: transactionKind,
    paymentMethod: PaymentMethodKind.upi,
    sourceLabel: sourceLabel,
    fundingSourceLabel: fundingSourceLabel,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}
