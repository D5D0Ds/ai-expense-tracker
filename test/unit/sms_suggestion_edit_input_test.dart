import 'package:ai_expense_tracker/features/sms_suggestions/sms_suggestion_edit_input.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseEditedSuggestion', () {
    test('applies valid edits and trims optional labels', () {
      // Arrange
      final original = _parsedExpense();

      // Act
      final edited = parseEditedSuggestion(
        original: original,
        amountText: ' 900.50 ',
        payeeText: '  Big Basket  ',
        category: ExpenseCategory.shopping,
        transactionKind: TransactionKind.expense,
        paymentMethod: PaymentMethodKind.creditCard,
        accountHintText: ' Card XX1234 ',
        sourceLabelText: ' HSBC Credit Card ',
        fundingSourceLabelText: ' Salary Account ',
      );

      // Assert
      expect(edited, isNotNull);
      expect(edited?.amount, 900.5);
      expect(edited?.payee, 'Big Basket');
      expect(edited?.category, ExpenseCategory.shopping);
      expect(edited?.paymentMethod, PaymentMethodKind.creditCard);
      expect(edited?.accountHint, 'Card XX1234');
      expect(edited?.sourceLabel, 'HSBC Credit Card');
      expect(edited?.fundingSourceLabel, 'Salary Account');
      expect(edited?.reason, editedSuggestionReason);
      expect(edited?.date, original.date);
      expect(edited?.confidence, original.confidence);
    });

    test('converts blank optional fields to null', () {
      // Arrange
      final original = _parsedExpense(
        accountHint: 'A/c XX2182',
        sourceLabel: 'HDFC UPI',
        fundingSourceLabel: 'HDFC Account',
      );

      // Act
      final edited = parseEditedSuggestion(
        original: original,
        amountText: '642',
        payeeText: 'Swiggy',
        category: ExpenseCategory.food,
        transactionKind: TransactionKind.expense,
        paymentMethod: PaymentMethodKind.upi,
        accountHintText: ' ',
        sourceLabelText: '',
        fundingSourceLabelText: null,
      );

      // Assert
      expect(edited, isNotNull);
      expect(edited?.accountHint, isNull);
      expect(edited?.sourceLabel, isNull);
      expect(edited?.fundingSourceLabel, isNull);
    });

    test('returns null for invalid amount or blank payee', () {
      // Arrange
      final original = _parsedExpense();

      // Act
      final invalidAmount = parseEditedSuggestion(
        original: original,
        amountText: '-1',
        payeeText: 'Swiggy',
        category: ExpenseCategory.food,
        transactionKind: TransactionKind.expense,
        paymentMethod: PaymentMethodKind.upi,
      );
      final blankPayee = parseEditedSuggestion(
        original: original,
        amountText: '642',
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

ParsedExpense _parsedExpense({
  String? accountHint,
  String? sourceLabel,
  String? fundingSourceLabel,
}) {
  return ParsedExpense(
    amount: 642,
    currency: 'INR',
    date: DateTime(2026, 6, 1),
    payee: 'Swiggy',
    category: ExpenseCategory.food,
    confidence: 0.8,
    reason: 'Parsed on device.',
    isPersonLike: false,
    accountHint: accountHint,
    sourceLabel: sourceLabel,
    fundingSourceLabel: fundingSourceLabel,
  );
}
