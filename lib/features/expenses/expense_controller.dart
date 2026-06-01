import 'package:ai_expense_tracker/features/expenses/expense_ports.dart';
import 'package:ai_expense_tracker/features/expenses/expense_repository.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides confirmed expense list state.
final expenseControllerProvider =
    AsyncNotifierProvider<ExpenseController, List<Expense>>(
      ExpenseController.new,
    );

/// Controls confirmed expenses for list, details, dashboard, and reports.
final class ExpenseController extends AsyncNotifier<List<Expense>>
    implements ExpenseReloader {
  @override
  Future<List<Expense>> build() {
    return ref.watch(expenseRepositoryProvider).all();
  }

  /// Reloads expenses from disk.
  @override
  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(expenseRepositoryProvider).all(),
    );
  }

  /// Adds a manual expense.
  Future<void> addManual({
    required double amount,
    required String payee,
    required ExpenseCategory category,
    required TransactionKind transactionKind,
    required PaymentMethodKind paymentMethod,
    required DateTime occurredAt,
    String? notes,
    String? accountHint,
    String? sourceLabel,
    String? fundingSourceLabel,
  }) async {
    await ref
        .read(expenseRepositoryProvider)
        .addManual(
          amount: amount,
          payee: payee,
          category: category,
          transactionKind: transactionKind,
          paymentMethod: paymentMethod,
          occurredAt: occurredAt,
          notes: notes,
          accountHint: accountHint,
          sourceLabel: sourceLabel,
          fundingSourceLabel: fundingSourceLabel,
        );
    await reload();
  }

  /// Replaces an expense.
  Future<void> upsert(Expense expense) async {
    await ref.read(expenseRepositoryProvider).upsert(expense);
    await reload();
  }

  /// Deletes an expense.
  Future<void> delete(String id) async {
    await ref.read(expenseRepositoryProvider).delete(id);
    await reload();
  }
}

/// Provides the selected expense by id.
final expenseByIdProvider = FutureProvider.family<Expense?, String>((ref, id) {
  return ref.watch(expenseRepositoryProvider).byId(id);
});
