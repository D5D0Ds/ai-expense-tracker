import 'package:ai_expense_tracker/shared/core/domain_models.dart';

/// Reloads confirmed expense state.
abstract interface class ExpenseReloader {
  /// Reloads confirmed expenses from the source of truth.
  Future<void> reload();
}

/// Converts a parsed SMS proposal into a confirmed expense.
abstract interface class ParsedExpenseConfirmer {
  /// Confirms parsed SMS output as an expense.
  Future<Expense> confirmParsed({
    required ParsedExpense parsed,
    required String smsHash,
    String? notes,
  });
}

/// Marks confirmed expenses as exported.
abstract interface class ExpenseExportMarker {
  /// Marks expenses as exported.
  Future<void> markExported(Iterable<String> ids);
}
