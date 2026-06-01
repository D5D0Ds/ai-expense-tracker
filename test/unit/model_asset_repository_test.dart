import 'package:ai_expense_tracker/features/model_asset/model_asset_repository.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_app_database.dart';

void main() {
  group('ModelAssetRepository', () {
    test('returns null when no state is cached', () {
      // Arrange
      final repository = ModelAssetRepository(FakeAppDatabase());

      // Act
      final state = repository.loadState();

      // Assert
      expect(state, isNull);
    });

    test('saves and loads model state', () async {
      // Arrange
      final repository = ModelAssetRepository(FakeAppDatabase());
      const state = ModelAssetState(
        phase: ModelAssetPhase.ready,
        path: '/models/gemma.litertlm',
        receivedBytes: 120,
        totalBytes: 120,
        bytesPerSecond: 10,
        eta: Duration(seconds: 2),
        message: 'Ready',
      );

      // Act
      await repository.saveState(state);
      final loaded = repository.loadState();

      // Assert
      expect(loaded?.phase, ModelAssetPhase.ready);
      expect(loaded?.path, '/models/gemma.litertlm');
      expect(loaded?.receivedBytes, 120);
      expect(loaded?.totalBytes, 120);
      expect(loaded?.bytesPerSecond, 10);
      expect(loaded?.eta, const Duration(seconds: 2));
      expect(loaded?.message, 'Ready');
    });
  });
}
