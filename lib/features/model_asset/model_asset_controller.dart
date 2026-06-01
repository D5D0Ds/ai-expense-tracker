import 'package:ai_expense_tracker/features/model_asset/model_asset_repository.dart';
import 'package:ai_expense_tracker/features/model_asset/model_asset_service.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/platform/gemma_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides model asset state.
final modelAssetControllerProvider =
    AsyncNotifierProvider<ModelAssetController, ModelAssetState>(
      ModelAssetController.new,
    );

/// Controls model checks, downloads, cancellation, and native loading.
final class ModelAssetController extends AsyncNotifier<ModelAssetState> {
  @override
  Future<ModelAssetState> build() async {
    final cached = ref.watch(modelAssetRepositoryProvider).loadState();
    if (cached != null) state = AsyncData(cached);
    return check();
  }

  /// Checks local model readiness.
  Future<ModelAssetState> check() async {
    state = const AsyncData(
      ModelAssetState(
        phase: ModelAssetPhase.checking,
        message: 'Checking model',
      ),
    );
    final next = await ref.read(modelAssetServiceProvider).check();
    await _persist(next);
    if (next.isReady && next.path != null) {
      await ref.read(gemmaGatewayProvider).loadModel(next.path!);
    }
    state = AsyncData(next);
    return next;
  }

  /// Starts the model download.
  Future<void> download() async {
    final service = ref.read(modelAssetServiceProvider);
    final result = await service.download(
      onProgress: (progress) {
        state = AsyncData(progress);
        _persist(progress);
      },
    );
    await _persist(result);
    if (result.isReady && result.path != null) {
      await ref.read(gemmaGatewayProvider).loadModel(result.path!);
    }
    state = AsyncData(result);
  }

  /// Cancels an active download.
  void cancel() {
    ref.read(modelAssetServiceProvider).cancel();
  }

  Future<void> _persist(ModelAssetState next) async {
    await ref.read(modelAssetRepositoryProvider).saveState(next);
  }
}
