import 'package:ai_expense_tracker/features/expenses/expense_api.dart';
import 'package:ai_expense_tracker/features/expenses/expense_controller.dart';
import 'package:ai_expense_tracker/features/expenses/expense_repository.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:ai_expense_tracker/shared/persistence/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_app_database.dart';

void main() {
  group('Expense API Providers', () {
    late ProviderContainer container;
    late FakeAppDatabase database;

    setUp(() {
      database = FakeAppDatabase();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          nowProvider.overrideWithValue(() => DateTime(2026, 6, 1)),
          idGeneratorProvider.overrideWithValue(() => 'test-id'),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('confirmedExpensesProvider returns controller state', () async {
      final state = container.read(confirmedExpensesProvider);
      expect(state, isA<AsyncValue<List<Expense>>>());
    });

    test('expenseReloaderProvider returns controller notifier', () {
      final reloader = container.read(expenseReloaderProvider);
      expect(reloader, isA<ExpenseController>());
    });

    test('parsedExpenseConfirmerProvider returns repository', () {
      final confirmer = container.read(parsedExpenseConfirmerProvider);
      expect(confirmer, isA<ExpenseRepository>());
    });

    test('expenseExportMarkerProvider returns repository', () {
      final marker = container.read(expenseExportMarkerProvider);
      expect(marker, isA<ExpenseRepository>());
    });
  });
}
