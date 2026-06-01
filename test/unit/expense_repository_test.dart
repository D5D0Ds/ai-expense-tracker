import 'package:ai_expense_tracker/features/expenses/expense_repository.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_app_database.dart';

void main() {
  group('ExpenseRepository', () {
    test(
      'addManual creates a trimmed manual expense with injected id and time',
      () async {
        // Arrange
        final now = DateTime(2026, 6, 1, 12);
        final repository = ExpenseRepository(
          database: FakeAppDatabase(),
          now: () => now,
          generateId: () => 'expense-1',
        );

        // Act
        final expense = await repository.addManual(
          amount: 250,
          payee: '  Swiggy  ',
          category: ExpenseCategory.food,
          transactionKind: TransactionKind.expense,
          paymentMethod: PaymentMethodKind.upi,
          occurredAt: DateTime(2026, 6, 1, 10),
          notes: '  lunch  ',
          accountHint: '  ',
          sourceLabel: ' HDFC UPI ',
          fundingSourceLabel: ' HDFC Account ',
        );

        // Assert
        expect(expense.id, 'expense-1');
        expect(expense.payee, 'Swiggy');
        expect(expense.notes, 'lunch');
        expect(expense.accountHint, isNull);
        expect(expense.sourceLabel, 'HDFC UPI');
        expect(expense.fundingSourceLabel, 'HDFC Account');
        expect(expense.createdAt, now);
        expect(expense.updatedAt, now);
        expect(await repository.byId('expense-1'), isNotNull);
      },
    );

    test(
      'confirmParsed creates an SMS expense with injected id and time',
      () async {
        // Arrange
        final now = DateTime(2026, 6, 1, 12);
        final parsedDate = DateTime(2026, 6, 1, 9);
        final repository = ExpenseRepository(
          database: FakeAppDatabase(),
          now: () => now,
          generateId: () => 'sms-expense-1',
        );
        final parsed = ParsedExpense(
          amount: 642,
          currency: 'INR',
          date: parsedDate,
          payee: 'Swiggy',
          category: ExpenseCategory.food,
          confidence: 0.8,
          reason: 'Parsed on device.',
          isPersonLike: false,
          sourceLabel: ' HDFC UPI ',
        );

        // Act
        final expense = await repository.confirmParsed(
          parsed: parsed,
          smsHash: 'hash-1',
          notes: '  delivery  ',
        );

        // Assert
        expect(expense.id, 'sms-expense-1');
        expect(expense.source, ExpenseSource.sms);
        expect(expense.occurredAt, parsedDate);
        expect(expense.rawSmsHash, 'hash-1');
        expect(expense.notes, 'delivery');
        expect(expense.sourceLabel, 'HDFC UPI');
        expect(expense.createdAt, now);
        expect(expense.updatedAt, now);
      },
    );

    test(
      'markExported updates only existing expenses with injected time',
      () async {
        // Arrange
        final createdAt = DateTime(2026, 6, 1);
        final exportedAt = DateTime(2026, 6, 2);
        final database = FakeAppDatabase();
        final repository = ExpenseRepository(
          database: database,
          now: () => createdAt,
          generateId: () => 'expense-1',
        );
        await repository.addManual(
          amount: 250,
          payee: 'Swiggy',
          category: ExpenseCategory.food,
          transactionKind: TransactionKind.expense,
          paymentMethod: PaymentMethodKind.upi,
          occurredAt: createdAt,
        );
        final exportRepository = ExpenseRepository(
          database: database,
          now: () => exportedAt,
          generateId: () => 'unused',
        );

        // Act
        await exportRepository.markExported(['expense-1', 'missing']);
        final expense = await exportRepository.byId('expense-1');

        // Assert
        expect(expense?.exportedAt, exportedAt);
        expect(expense?.updatedAt, exportedAt);
      },
    );
  });
}
