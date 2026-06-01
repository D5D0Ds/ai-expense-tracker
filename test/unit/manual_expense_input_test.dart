import 'package:ai_expense_tracker/features/expenses/manual_expense_input.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseManualExpenseInput', () {
    test('parses and trims a valid manual expense', () {
      // Arrange / Act
      final input = parseManualExpenseInput(
        amountText: ' 250.50 ',
        payeeText: '  Swiggy  ',
        category: ExpenseCategory.food,
        transactionKind: TransactionKind.expense,
        paymentMethod: PaymentMethodKind.upi,
        notesText: ' lunch ',
        accountHintText: ' A/c XX2182 ',
        sourceLabelText: ' HDFC UPI ',
        fundingSourceLabelText: ' HDFC Account ',
      );

      // Assert
      expect(input, isNotNull);
      expect(input?.amount, 250.5);
      expect(input?.payee, 'Swiggy');
      expect(input?.category, ExpenseCategory.food);
      expect(input?.transactionKind, TransactionKind.expense);
      expect(input?.paymentMethod, PaymentMethodKind.upi);
      expect(input?.notes, 'lunch');
      expect(input?.accountHint, 'A/c XX2182');
      expect(input?.sourceLabel, 'HDFC UPI');
      expect(input?.fundingSourceLabel, 'HDFC Account');
    });

    test('converts blank optional fields to null', () {
      // Arrange / Act
      final input = parseManualExpenseInput(
        amountText: '100',
        payeeText: 'Metro',
        category: ExpenseCategory.travel,
        transactionKind: TransactionKind.expense,
        paymentMethod: PaymentMethodKind.creditCard,
        notesText: ' ',
        accountHintText: '',
        sourceLabelText: null,
        fundingSourceLabelText: '  ',
      );

      // Assert
      expect(input, isNotNull);
      expect(input?.notes, isNull);
      expect(input?.accountHint, isNull);
      expect(input?.sourceLabel, isNull);
      expect(input?.fundingSourceLabel, isNull);
    });

    test('returns null for invalid amount or blank payee', () {
      // Arrange / Act
      final invalidAmount = parseManualExpenseInput(
        amountText: '0',
        payeeText: 'Swiggy',
        category: ExpenseCategory.food,
        transactionKind: TransactionKind.expense,
        paymentMethod: PaymentMethodKind.upi,
      );
      final blankPayee = parseManualExpenseInput(
        amountText: '100',
        payeeText: '   ',
        category: ExpenseCategory.food,
        transactionKind: TransactionKind.expense,
        paymentMethod: PaymentMethodKind.upi,
      );

      // Assert
      expect(invalidAmount, isNull);
      expect(blankPayee, isNull);
    });
  });
}
