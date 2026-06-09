import 'package:ai_expense_tracker/features/expenses/expense_controller.dart';
import 'package:ai_expense_tracker/features/expenses/expense_ports.dart';
import 'package:ai_expense_tracker/features/expenses/expense_repository.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'expense_ports.dart';
export 'expense_repository.dart' show expenseRepositoryProvider;

/// Read-only access to confirmed expenses for other features.
final confirmedExpensesProvider = Provider<AsyncValue<List<Expense>>>((ref) {
  return ref.watch(expenseControllerProvider);
});

/// Provides an operation that reloads confirmed expense state.
final expenseReloaderProvider = Provider<ExpenseReloader>((ref) {
  return ref.watch(expenseControllerProvider.notifier);
});

/// Provides parsed SMS confirmation for features outside expenses.
final parsedExpenseConfirmerProvider = Provider<ParsedExpenseConfirmer>((ref) {
  return ref.watch(expenseRepositoryProvider);
});

/// Provides report export marking for features outside expenses.
final expenseExportMarkerProvider = Provider<ExpenseExportMarker>((ref) {
  return ref.watch(expenseRepositoryProvider);
});
