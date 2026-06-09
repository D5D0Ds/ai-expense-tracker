import 'package:ai_expense_tracker/shared/persistence/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides persisted monthly budget storage.
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(appDatabaseProvider));
});

/// Repository that owns budget persistence.
final class BudgetRepository {
  /// Creates a budget repository.
  const BudgetRepository(this._database);

  static const _key = 'monthly_budgets';

  final AppDatabase _database;

  /// Loads all month-keyed budgets.
  Map<String, double> loadAll() {
    final cached = _database.settings.get(_key);
    if (cached is! Map) return {};

    final budgets = <String, double>{};
    for (final entry in cached.entries) {
      final value = entry.value;
      if (value is num) {
        budgets[entry.key.toString()] = value.toDouble();
      }
    }
    return budgets;
  }

  /// Saves all month-keyed budgets.
  Future<void> saveAll(Map<String, double> budgets) async {
    await _database.settings.put(_key, budgets);
  }
}
