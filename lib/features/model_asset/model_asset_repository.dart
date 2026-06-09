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

    final rawPhase = cached['phase'] as Object?;
    if (rawPhase != null && rawPhase is! String) return null;
    final phaseName = rawPhase ?? ModelAssetPhase.absent.name;
    final phase = ModelAssetPhase.values
        .where((candidate) => candidate.name == phaseName)
        .firstOrNull;
    if (phase == null) return null;

    final rawPath = cached['path'] as Object?;
    final rawReceivedBytes = cached['receivedBytes'] as Object?;
    final rawTotalBytes = cached['totalBytes'] as Object?;
    final rawBytesPerSecond = cached['bytesPerSecond'] as Object?;
    final rawEtaSeconds = cached['etaSeconds'] as Object?;
    final rawMessage = cached['message'] as Object?;

    if (rawPath != null && rawPath is! String) return null;
    if (rawReceivedBytes != null && rawReceivedBytes is! int) return null;
    if (rawTotalBytes != null && rawTotalBytes is! int) return null;
    if (rawBytesPerSecond != null && rawBytesPerSecond is! num) return null;
    if (rawEtaSeconds != null && rawEtaSeconds is! int) return null;
    if (rawMessage != null && rawMessage is! String) return null;

    final path = rawPath as String?;
    final receivedBytes = rawReceivedBytes as int? ?? 0;
    final totalBytes = rawTotalBytes as int? ?? 0;
    final bytesPerSecond = (rawBytesPerSecond as num?)?.toDouble() ?? 0;
    final etaSeconds = rawEtaSeconds as int?;
    final message = rawMessage as String?;

    return ModelAssetState(
      phase: phase,
      path: path,
      receivedBytes: receivedBytes,
      totalBytes: totalBytes,
      bytesPerSecond: bytesPerSecond,
      eta: etaSeconds == null ? null : Duration(seconds: etaSeconds),
      message: message,
    );
  }

  /// Saves the latest model state.
  Future<void> saveState(ModelAssetState state) async {
    await _database.settings.put(_stateKey, state.toJson());
  }
}
