import 'package:ai_expense_tracker/features/settings/budget_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseBudgetAmount', () {
    test('parses trimmed positive and zero values', () {
      // Act / Assert
      expect(parseBudgetAmount(' 40000 '), 40000);
      expect(parseBudgetAmount('0'), 0);
    });

    test('rejects blank, invalid, and negative values', () {
      // Act / Assert
      expect(parseBudgetAmount(''), isNull);
      expect(parseBudgetAmount('abc'), isNull);
      expect(parseBudgetAmount('-1'), isNull);
    });
  });
}
