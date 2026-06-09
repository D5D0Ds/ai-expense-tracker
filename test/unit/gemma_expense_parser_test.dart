import 'package:ai_expense_tracker/features/sms_suggestions/gemma_expense_parser.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/platform/exchange_rate_service.dart';
import 'package:ai_expense_tracker/shared/platform/gemma_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGemmaGateway extends Mock implements GemmaGateway {}

class _MockExchangeRateService extends Mock implements ExchangeRateService {}

/// Minimal [ParsedExpense] factory for tests.
ParsedExpense _expense({
  double amount = 100,
  String currency = 'INR',
  String reason = 'Test reason',
}) => ParsedExpense(
  amount: amount,
  currency: currency,
  date: DateTime(2026, 6, 9),
  payee: 'Test',
  category: ExpenseCategory.other,
  confidence: 0.9,
  reason: reason,
  isPersonLike: false,
);

void main() {
  late _MockGemmaGateway mockBridge;
  late _MockExchangeRateService mockRates;
  late GemmaExpenseParser parser;

  setUp(() {
    mockBridge = _MockGemmaGateway();
    mockRates = _MockExchangeRateService();
    parser = GemmaExpenseParser(bridge: mockBridge, rates: mockRates);
  });

  group('GemmaExpenseParser', () {
    test('passes through INR amounts unchanged', () async {
      final inr = _expense(amount: 500, currency: 'INR');
      when(() => mockBridge.parseSms(any())).thenAnswer((_) async => inr);

      final result = await parser.parse('debited INR 500');

      expect(result.amount, 500);
      expect(result.currency, 'INR');
      verifyNever(() => mockRates.getRate());
    });

    test('converts USD amounts using live rate', () async {
      final usdExpense = _expense(amount: 10, currency: 'USD');
      when(() => mockBridge.parseSms(any())).thenAnswer((_) async => usdExpense);
      when(() => mockRates.getRate()).thenReturn(84.5);

      final result = await parser.parse('charged USD 10');

      expect(result.amount, 845.0);
      expect(result.currency, 'INR');
      expect(result.reason, contains('84.5'));
    });

    test('converts dollar-sign amounts using live rate', () async {
      final dollarExpense = _expense(amount: 5.5, currency: r'$');
      when(() => mockBridge.parseSms(any())).thenAnswer((_) async => dollarExpense);
      when(() => mockRates.getRate()).thenReturn(84.0);

      final result = await parser.parse(r'charged $5.5');

      expect(result.amount, closeTo(5.5 * 84.0, 0.01));
      expect(result.currency, 'INR');
    });

    test('handles lowercase usd currency symbol', () async {
      final usdLower = _expense(amount: 20, currency: 'usd');
      when(() => mockBridge.parseSms(any())).thenAnswer((_) async => usdLower);
      when(() => mockRates.getRate()).thenReturn(85.0);

      final result = await parser.parse('charged usd 20');

      expect(result.amount, 1700.0);
      expect(result.currency, 'INR');
    });

    test('throws StateError when Gemma returns null', () async {
      when(() => mockBridge.parseSms(any())).thenAnswer((_) async => null);

      expect(
        () => parser.parse('some sms'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
