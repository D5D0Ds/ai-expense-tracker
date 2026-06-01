import 'package:ai_expense_tracker/features/sms_suggestions/gemma_expense_parser.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GemmaExpenseParser fallback', () {
    test('extracts amount, payee, food category, and account hint', () {
      final fallbackDate = DateTime(2026, 6, 1, 12);
      final parsed = GemmaExpenseParser.parseWithHeuristics(
        'HDFC Bank: Rs. 642.00 debited from A/c XX2182 via UPI to SWIGGY on 01-Jun.',
        fallbackDate: fallbackDate,
      );

      expect(parsed.amount, 642);
      expect(parsed.date, fallbackDate);
      expect(parsed.payee.toLowerCase(), contains('swiggy'));
      expect(parsed.category, ExpenseCategory.food);
      expect(parsed.paymentMethod, PaymentMethodKind.upi);
      expect(parsed.sourceLabel, contains('HDFC'));
      expect(parsed.fundingSourceLabel, contains('Account'));
      expect(parsed.accountHint, isNotNull);
    });

    test('suggests lent when payee looks like a person', () {
      final parsed = GemmaExpenseParser.parseWithHeuristics(
        'SBI: INR 1200 paid to Rahul Sharma via UPI ref 121212.',
      );

      expect(parsed.transactionKind, TransactionKind.lent);
      expect(parsed.category, ExpenseCategory.transfer);
      expect(parsed.isPersonLike, isTrue);
    });

    test('suggests borrowed when an incoming person transfer is detected', () {
      final parsed = GemmaExpenseParser.parseWithHeuristics(
        'Kotak Bank: INR 2500 received from Ananya Singh via UPI to A/c XX1044.',
      );

      expect(parsed.transactionKind, TransactionKind.borrowed);
      expect(parsed.paymentMethod, PaymentMethodKind.upi);
      expect(parsed.fundingSourceLabel, contains('Account'));
    });
  });
}
