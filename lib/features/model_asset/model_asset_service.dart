import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:ai_expense_tracker/features/model_asset/model_asset_config.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Provides model file storage operations.
final modelAssetStorageProvider = Provider<ModelAssetStorage>((ref) {
  return const AppSupportModelAssetStorage();
});

/// Provides the model service.
final modelAssetServiceProvider = Provider<ModelAssetService>((ref) {
  return ModelAssetService(
    storage: ref.watch(modelAssetStorageProvider),
    now: ref.watch(nowProvider),
  );
});

/// Filesystem operations required by model asset management.
abstract interface class ModelAssetStorage {
  /// Returns the target model path.
  Future<String> modelPath();

  /// Prepares and returns the partial download path.
  Future<String> preparePartialDownload(String modelPath);

  /// Replaces the model file with a completed partial download.
  Future<void> completePartialDownload({
    required String modelPath,
    required String partialPath,
  });

  /// Inspects the local model file.
  Future<ModelAssetState> inspect(String modelPath);
}

/// App support directory-backed model storage.
final class AppSupportModelAssetStorage implements ModelAssetStorage {
  /// Creates storage.
  const AppSupportModelAssetStorage();

  @override
  Future<String> modelPath() async {
    final directory = await getApplicationSupportDirectory();
    return p.join(directory.path, 'models', gemmaModelFilename);
  }

  @override
  Future<String> preparePartialDownload(String modelPath) async {
    final file = File(modelPath);
    final partial = File('$modelPath.part');
    await file.parent.create(recursive: true);
    if (await partial.exists()) await partial.delete();
    return partial.path;
  }

  @override
  Future<void> completePartialDownload({
    required String modelPath,
    required String partialPath,
  }) async {
    final file = File(modelPath);
    if (await file.exists()) await file.delete();
    await File(partialPath).rename(modelPath);
  }

  @override
  Future<ModelAssetState> inspect(String modelPath) async {
    return Isolate.run(() => inspectModelFile(modelPath));
  }
}

/// Provides model file inspection and download.
final class ModelAssetService {
  /// Creates a service.
  ModelAssetService({
    required this.storage,
    required this.now,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  /// Storage boundary used for model file operations.
  final ModelAssetStorage storage;

  /// Clock used for download progress calculations.
  final DateTime Function() now;

  final Dio _dio;
  CancelToken? _cancelToken;

  /// Returns the target model path.
  Future<String> modelPath() => storage.modelPath();

  /// Checks whether a local model file is ready.
  Future<ModelAssetState> check() async {
    final path = await modelPath();
    return storage.inspect(path);
  }

  /// Downloads the model with progress callbacks.
  Future<ModelAssetState> download({
    required void Function(ModelAssetState state) onProgress,
  }) async {
    final path = await modelPath();
    final partialPath = await storage.preparePartialDownload(path);

    var lastEmitTime = now();
    var lastEmitBytes = 0;
    const minEmitIntervalMs = 500;
    _cancelToken = CancelToken();

    try {
      await _dio.download(
        gemmaModelUrl,
        partialPath,
        cancelToken: _cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          final currentTime = now();
          final totalBytes = total > 0 ? total : gemmaExpectedBytes;
          final isComplete = received >= totalBytes;

          if (!isComplete) {
            final elapsedMs = currentTime
                .difference(lastEmitTime)
                .inMilliseconds;
            if (elapsedMs < minEmitIntervalMs) return;
          }

          final elapsedMs = currentTime.difference(lastEmitTime).inMilliseconds;
          final delta = received - lastEmitBytes;
          final speed = elapsedMs <= 0 ? 0 : delta * 1000 / elapsedMs;

          lastEmitTime = currentTime;
          lastEmitBytes = received;

          final eta = speed <= 0 || totalBytes <= received
              ? null
              : Duration(
                  seconds: ((totalBytes - received) / speed).ceil(),
                );
          onProgress(
            ModelAssetState(
              phase: ModelAssetPhase.downloading,
              path: path,
              receivedBytes: received,
              totalBytes: totalBytes,
              bytesPerSecond: speed.toDouble(),
              eta: eta,
              message: 'Downloading Gemma 4 E2B',
            ),
          );
        },
      );

      await storage.completePartialDownload(
        modelPath: path,
        partialPath: partialPath,
      );
      return check();
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return const ModelAssetState(
          phase: ModelAssetPhase.cancelled,
          message: 'Download cancelled',
        );
      }
      return ModelAssetState(
        phase: ModelAssetPhase.failed,
        message: 'Model download failed: ${error.message ?? error.type.name}',
      );
    }
  }

  /// Cancels an active download.
  void cancel() {
    _cancelToken?.cancel('User cancelled download');
  }
}

/// Inspects a model file path.
ModelAssetState inspectModelFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return const ModelAssetState.absent();
  final size = file.lengthSync();
  if (!isValidGemmaModelSize(size)) {
    return ModelAssetState(
      phase: ModelAssetPhase.failed,
      path: path,
      totalBytes: size,
      message: 'Found model file, but size is not within +/-5 MB.',
    );
  }
  return ModelAssetState(
    phase: ModelAssetPhase.ready,
    path: path,
    receivedBytes: size,
    totalBytes: size,
    message: 'Gemma 4 E2B is ready',
  );
}
