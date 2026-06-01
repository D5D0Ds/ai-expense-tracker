import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/persistence/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides persisted model asset metadata.
final modelAssetRepositoryProvider = Provider<ModelAssetRepository>((ref) {
  return ModelAssetRepository(ref.watch(appDatabaseProvider));
});

/// Repository that owns model asset state persistence.
final class ModelAssetRepository {
  /// Creates a model asset repository.
  const ModelAssetRepository(this._database);

  static const _stateKey = 'modelState';

  final AppDatabase _database;

  /// Loads the last known model state.
  ModelAssetState? loadState() {
    final cached = _database.settings.get(_stateKey);
    if (cached is! Map<dynamic, dynamic>) return null;
    return ModelAssetState.fromJson(cached);
  }

  /// Saves the latest model state.
  Future<void> saveState(ModelAssetState state) async {
    await _database.settings.put(_stateKey, state.toJson());
  }
}
