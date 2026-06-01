import 'package:ai_expense_tracker/features/settings/budget_controller.dart';
import 'package:ai_expense_tracker/shared/persistence/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_app_database.dart';

void main() {
  group('BudgetController', () {
    late FakeAppDatabase database;
    late ProviderContainer container;

    setUp(() {
      database = FakeAppDatabase();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty when no cache exists', () {
      final state = container.read(budgetControllerProvider);
      expect(state, isEmpty);
    });

    test('returns default budget when no budget is saved', () {
      final controller = container.read(budgetControllerProvider.notifier);
      final budget = controller.getBudgetForMonth(DateTime(2026, 6));
      expect(budget, 40000);
    });

    test('saves and retrieves exact month budget', () async {
      final controller = container.read(budgetControllerProvider.notifier);
      await controller.setBudget('2026-06', 30000);

      final state = container.read(budgetControllerProvider);
      expect(state['2026-06'], 30000);

      final budget = controller.getBudgetForMonth(DateTime(2026, 6));
      expect(budget, 30000);
    });

    test(
      'retrieves closest past month budget when no exact match exists',
      () async {
        final controller = container.read(budgetControllerProvider.notifier);
        await controller.setBudget('2026-04', 45000);
        await controller.setBudget('2026-06', 30000);

        // Querying May 2026 should fall back to April 2026 (45000)
        final budgetMay = controller.getBudgetForMonth(DateTime(2026, 5));
        expect(budgetMay, 45000);

        // Querying July 2026 should fall back to June 2026 (30000)
        final budgetJuly = controller.getBudgetForMonth(DateTime(2026, 7));
        expect(budgetJuly, 30000);
      },
    );

    test(
      'retrieves oldest budget if query date is before any recorded budget',
      () async {
        final controller = container.read(budgetControllerProvider.notifier);
        await controller.setBudget('2026-06', 30000);

        // Querying May 2026 (before first budget in June) should fallback to June budget (30000)
        final budgetMay = controller.getBudgetForMonth(DateTime(2026, 5));
        expect(budgetMay, 30000);
      },
    );
  });
}
