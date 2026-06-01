import 'package:ai_expense_tracker/features/reports/reports_controller.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrendFilterNotifier', () {
    test('builds a deterministic six-month default date window', () {
      // Arrange
      final container = ProviderContainer(
        overrides: [
          nowProvider.overrideWithValue(() => DateTime(2026, 6, 15)),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final filter = container.read(trendFilterProvider);

      // Assert
      expect(filter.startDate, DateTime(2026, 1));
      expect(filter.endDate, DateTime(2026, 6, 30));
      expect(filter.category, isNull);
      expect(filter.paymentMethod, isNull);
      expect(filter.transactionKind, isNull);
      expect(filter.account, isNull);
    });
  });
}
