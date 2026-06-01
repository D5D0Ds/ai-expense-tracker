import 'package:ai_expense_tracker/features/expenses/expense_ports.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:ai_expense_tracker/shared/core/text_normalization.dart';
import 'package:ai_expense_tracker/shared/persistence/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the expense repository.
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(
    database: ref.watch(appDatabaseProvider),
    now: ref.watch(nowProvider),
    generateId: ref.watch(idGeneratorProvider),
  );
});

/// Repository that owns confirmed expense persistence.
final class ExpenseRepository
    implements ParsedExpenseConfirmer, ExpenseExportMarker {
  /// Creates an expense repository.
  ExpenseRepository({
    required AppDatabase database,
    required DateTime Function() now,
    required String Function() generateId,
  }) : this._(
         database,
         now,
         generateId,
       );

  ExpenseRepository._(
    this._database,
    this._now,
    this._generateId,
  );

  final AppDatabase _database;
  final DateTime Function() _now;
  final String Function() _generateId;

  /// Returns all confirmed expenses ordered newest first.
  Future<List<Expense>> all() async {
    final expenses =
        _database.expenses.values
            .whereType<Map<dynamic, dynamic>>()
            .map(Expense.fromJson)
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return expenses;
  }

  /// Finds an expense by id.
  Future<Expense?> byId(String id) async {
    final value = _database.expenses.get(id);
    if (value is! Map<dynamic, dynamic>) return null;
    return Expense.fromJson(value);
  }

  /// Adds a manually entered expense.
  Future<Expense> addManual({
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
    final now = _now();
    final expense = Expense(
      id: _generateId(),
      amount: amount,
      currency: 'INR',
      occurredAt: occurredAt,
      payee: payee.trim(),
      category: category,
      source: ExpenseSource.manual,
      transactionKind: transactionKind,
      paymentMethod: paymentMethod,
      accountHint: trimToNull(accountHint),
      notes: trimToNull(notes),
      sourceLabel: trimToNull(sourceLabel),
      fundingSourceLabel: trimToNull(fundingSourceLabel),
      createdAt: now,
      updatedAt: now,
    );
    await upsert(expense);
    return expense;
  }

  /// Adds or replaces an expense.
  Future<void> upsert(Expense expense) async {
    await _database.expenses.put(expense.id, expense.toJson());
  }

  /// Deletes an expense.
  Future<void> delete(String id) async {
    await _database.expenses.delete(id);
  }

  /// Marks expenses as exported.
  @override
  Future<void> markExported(Iterable<String> ids) async {
    final exportedAt = _now();
    for (final id in ids) {
      final expense = await byId(id);
      if (expense == null) continue;
      await upsert(
        expense.copyWith(exportedAt: exportedAt, updatedAt: exportedAt),
      );
    }
  }

  /// Converts parsed SMS output into a confirmed expense.
  @override
  Future<Expense> confirmParsed({
    required ParsedExpense parsed,
    required String smsHash,
    String? notes,
  }) async {
    final now = _now();
    final expense = Expense(
      id: _generateId(),
      amount: parsed.amount,
      currency: parsed.currency,
      occurredAt: parsed.date,
      payee: parsed.payee,
      category: parsed.category,
      source: ExpenseSource.sms,
      transactionKind: parsed.transactionKind,
      paymentMethod: parsed.paymentMethod,
      accountHint: parsed.accountHint,
      rawSmsHash: smsHash,
      confidence: parsed.confidence,
      reason: parsed.reason,
      notes: trimToNull(notes),
      sourceLabel: trimToNull(parsed.sourceLabel),
      fundingSourceLabel: trimToNull(parsed.fundingSourceLabel),
      createdAt: now,
      updatedAt: now,
    );
    await upsert(expense);
    return expense;
  }
}
