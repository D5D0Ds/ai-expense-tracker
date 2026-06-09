import 'package:ai_expense_tracker/features/expenses/expense_ports.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:ai_expense_tracker/shared/core/text_normalization.dart';
import 'package:ai_expense_tracker/shared/persistence/app_database.dart';
import 'package:ai_expense_tracker/shared/persistence/json_box_store.dart';
import 'package:collection/collection.dart';
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
    AppDatabase database,
    this._now,
    this._generateId,
  ) : _store = JsonBoxStore<Expense>(
        box: database.expenses,
        fromJson: Expense.fromJson,
        toJson: (expense) => expense.toJson(),
        idOf: (expense) => expense.id,
      ),
      _smsStore = JsonBoxStore<SmsCandidate>(
        box: database.smsCandidates,
        fromJson: SmsCandidate.fromJson,
        toJson: (candidate) => candidate.toJson(),
        idOf: (candidate) => candidate.id,
      );

  final JsonBoxStore<Expense> _store;
  final JsonBoxStore<SmsCandidate> _smsStore;
  final DateTime Function() _now;
  final String Function() _generateId;

  /// Returns all confirmed expenses ordered newest first.
  Future<List<Expense>> all() async =>
      _store.all()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  /// Finds an expense by id.
  Future<Expense?> byId(String id) async => _store.byId(id);

  /// Returns whether an expense linked to the given SMS hash already exists.
  Future<bool> hasRawSmsHash(String rawSmsHash) async {
    final expenses = await all();
    return expenses.any((expense) => expense.rawSmsHash == rawSmsHash);
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
    await _store.upsert(expense);
  }

  /// Deletes an expense.
  Future<void> delete(String id) async {
    final expense = await byId(id);
    if (expense != null && expense.rawSmsHash != null) {
      final candidates = _smsStore.all();
      final match = candidates.firstWhereOrNull(
        (candidate) => candidate.bodyHash == expense.rawSmsHash,
      );
      if (match != null) {
        await _smsStore.delete(match.id);
      }
    }
    await _store.delete(id);
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
