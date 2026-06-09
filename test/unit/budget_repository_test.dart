import 'package:ai_expense_tracker/features/settings/budget_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_app_database.dart';

void main() {
  group('BudgetRepository', () {
    test('returns empty budgets when no cache exists', () {
      // Arrange
      final repository = BudgetRepository(FakeAppDatabase());

      // Act
      final budgets = repository.loadAll();

      // Assert
      expect(budgets, isEmpty);
    });

    test('loads numeric budgets as doubles', () {
      // Arrange
      final settings = FakeBox();
      final database = FakeAppDatabase(settings: settings);
      settings.seed('monthly_budgets', {
        '2026-06': 30000,
        '2026-07': 32500.5,
      });
      final repository = BudgetRepository(database);

      // Act
      final budgets = repository.loadAll();

      // Assert
      expect(budgets, {
        '2026-06': 30000.0,
        '2026-07': 32500.5,
      });
    });

    test('ignores malformed budget entries', () {
      // Arrange
      final settings = FakeBox();
      final database = FakeAppDatabase(settings: settings);
      settings.seed('monthly_budgets', {
        '2026-06': 30000,
        'bad': 'not-a-number',
      });
      final repository = BudgetRepository(database);

      // Act
      final budgets = repository.loadAll();

      // Assert
      expect(budgets, {'2026-06': 30000.0});
    });

    test('saves budgets under the monthly budgets key', () async {
      // Arrange
      final database = FakeAppDatabase();
      final repository = BudgetRepository(database);

      // Act
      await repository.saveAll({'2026-06': 30000});

      // Assert
      expect(database.settings.get('monthly_budgets'), {'2026-06': 30000});
    });
  });
}
