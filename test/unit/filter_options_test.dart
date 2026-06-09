import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/filter_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildNullableFilterOptions', () {
    test('builds an all option and unselected values', () {
      // Act
      final options = buildNullableFilterOptions<TransactionKind>(
        selected: null,
        values: TransactionKind.values,
        labelFor: (kind) => kind.label,
        accentFor: (kind) => kind.accentValue,
      );

      // Assert
      expect(options.first.label, 'All');
      expect(options.first.selected, isTrue);
      expect(options.first.nextValue, isNull);
      expect(options[1].label, TransactionKind.expense.label);
      expect(options[1].selected, isFalse);
      expect(options[1].nextValue, TransactionKind.expense);
      expect(options[1].accentValue, TransactionKind.expense.accentValue);
    });

    test('selected value toggles back to null', () {
      // Act
      final options = buildNullableFilterOptions(
        selected: ExpenseCategory.food,
        values: ExpenseCategory.values,
        labelFor: (category) => category.label,
      );
      final food = options.singleWhere(
        (option) => option.label == ExpenseCategory.food.label,
      );

      // Assert
      expect(options.first.selected, isFalse);
      expect(food.selected, isTrue);
      expect(food.nextValue, isNull);
    });
  });
}
