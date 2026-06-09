import 'package:ai_expense_tracker/features/expenses/expense_controller.dart';
import 'package:ai_expense_tracker/features/expenses/expense_repository.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_app_database.dart';

void main() {
  group('ExpenseController', () {
    late FakeAppDatabase database;
    late ProviderContainer container;
    late DateTime nowTime;
    late List<String> generatedIds;
    int idIndex = 0;

    setUp(() {
      database = FakeAppDatabase();
      nowTime = DateTime(2026, 6, 1, 12);
      generatedIds = ['id-1', 'id-2', 'id-3'];
      idIndex = 0;

      container = ProviderContainer(
        overrides: [
          expenseRepositoryProvider.overrideWith((ref) => ExpenseRepository(
                database: database,
                now: () => nowTime,
                generateId: () => generatedIds[idIndex++ % generatedIds.length],
              )),
          nowProvider.overrideWithValue(() => nowTime),
          idGeneratorProvider.overrideWithValue(() => 'fallback-id'),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state builds list from repository', () async {
      // Add initial expense directly via repository
      final repo = container.read(expenseRepositoryProvider);
      await repo.addManual(
        amount: 100,
        payee: 'Swiggy',
        category: ExpenseCategory.food,
        transactionKind: TransactionKind.expense,
        paymentMethod: PaymentMethodKind.upi,
        occurredAt: DateTime(2026, 6, 1, 10),
      );

      final state = await container.read(expenseControllerProvider.future);
      expect(state, hasLength(1));
      expect(state.first.id, 'id-1');
      expect(state.first.payee, 'Swiggy');
    });

    test('reload fetches latest state', () async {
      final notifier = container.read(expenseControllerProvider.notifier);

      // Verify empty initial state
      var state = await container.read(expenseControllerProvider.future);
      expect(state, isEmpty);

      // Add expense to DB in the background
      final repo = container.read(expenseRepositoryProvider);
      await repo.addManual(
        amount: 200,
        payee: 'Zomato',
        category: ExpenseCategory.food,
        transactionKind: TransactionKind.expense,
        paymentMethod: PaymentMethodKind.upi,
        occurredAt: DateTime(2026, 6, 1, 11),
      );

      // Reload
      await notifier.reload();

      state = await container.read(expenseControllerProvider.future);
      expect(state, hasLength(1));
      expect(state.first.payee, 'Zomato');
    });

    test('addManual adds expense and reloads controller state', () async {
      final notifier = container.read(expenseControllerProvider.notifier);

      await notifier.addManual(
        amount: 300,
        payee: 'Uber',
        category: ExpenseCategory.travel,
        transactionKind: TransactionKind.expense,
        paymentMethod: PaymentMethodKind.cash,
        occurredAt: DateTime(2026, 6, 1, 9),
        notes: 'ride to work',
      );

      final state = await container.read(expenseControllerProvider.future);
      expect(state, hasLength(1));
      expect(state.first.id, 'id-1');
      expect(state.first.amount, 300);
      expect(state.first.payee, 'Uber');
      expect(state.first.notes, 'ride to work');
    });

    test('upsert updates expense and reloads controller state', () async {
      final notifier = container.read(expenseControllerProvider.notifier);

      // Add initial
      await notifier.addManual(
        amount: 300,
        payee: 'Uber',
        category: ExpenseCategory.travel,
        transactionKind: TransactionKind.expense,
        paymentMethod: PaymentMethodKind.cash,
        occurredAt: DateTime(2026, 6, 1, 9),
      );

      var state = await container.read(expenseControllerProvider.future);
      final expense = state.first;

      // Edit and upsert
      final updated = expense.copyWith(amount: 350, payee: 'Uber Premium');
      await notifier.upsert(updated);

      state = await container.read(expenseControllerProvider.future);
      expect(state, hasLength(1));
      expect(state.first.amount, 350);
      expect(state.first.payee, 'Uber Premium');
    });

    test('delete removes expense and reloads controller state', () async {
      final notifier = container.read(expenseControllerProvider.notifier);

      // Add expense
      await notifier.addManual(
        amount: 400,
        payee: 'Amazon',
        category: ExpenseCategory.shopping,
        transactionKind: TransactionKind.expense,
        paymentMethod: PaymentMethodKind.creditCard,
        occurredAt: DateTime(2026, 6, 1, 8),
      );

      var state = await container.read(expenseControllerProvider.future);
      expect(state, hasLength(1));
      final id = state.first.id;

      // Delete
      await notifier.delete(id);

      state = await container.read(expenseControllerProvider.future);
      expect(state, isEmpty);
    });

    test('expenseByIdProvider retrieves expense by id', () async {
      final repo = container.read(expenseRepositoryProvider);
      final expense = await repo.addManual(
        amount: 500,
        payee: 'Netflix',
        category: ExpenseCategory.entertainment,
        transactionKind: TransactionKind.expense,
        paymentMethod: PaymentMethodKind.creditCard,
        occurredAt: DateTime(2026, 6, 1, 7),
      );


      final fetched = await container.read(expenseByIdProvider(expense.id).future);
      expect(fetched, isNotNull);
      expect(fetched!.payee, 'Netflix');

      final fetchedMissing = await container.read(expenseByIdProvider('missing-id').future);
      expect(fetchedMissing, isNull);
    });
  });
}
