import 'dart:io';

import 'package:ai_expense_tracker/features/model_asset/model_asset_config.dart';
import 'package:ai_expense_tracker/features/model_asset/model_asset_service.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelAssetService', () {
    test('accepts exact expected Gemma model size', () {
      expect(isValidGemmaModelSize(gemmaExpectedBytes), isTrue);
    });

    test('accepts model sizes inside five megabyte tolerance', () {
      expect(
        isValidGemmaModelSize(
          gemmaExpectedBytes + gemmaSizeToleranceBytes,
        ),
        isTrue,
      );
      expect(
        isValidGemmaModelSize(
          gemmaExpectedBytes - gemmaSizeToleranceBytes,
        ),
        isTrue,
      );
    });

    test('rejects model sizes outside five megabyte tolerance', () {
      expect(
        isValidGemmaModelSize(
          gemmaExpectedBytes + gemmaSizeToleranceBytes + 1,
        ),
        isFalse,
      );
    });

    test('inspectModelFile returns absent when the file is missing', () {
      // Arrange
      final path = '${Directory.systemTemp.path}/missing-gemma-model';

      // Act
      final result = inspectModelFile(path);

      // Assert
      expect(result.phase, ModelAssetPhase.absent);
    });

    test('inspectModelFile rejects an invalid local file size', () async {
      // Arrange
      final directory = await Directory.systemTemp.createTemp(
        'model_asset_service_test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/$gemmaModelFilename');
      await file.writeAsString('too small');

      // Act
      final result = inspectModelFile(file.path);

      // Assert
      expect(result.phase, ModelAssetPhase.failed);
      expect(result.path, file.path);
      expect(result.totalBytes, file.lengthSync());
    });

    test('check delegates model path and inspection to storage', () async {
      // Arrange
      final storage = _FakeModelAssetStorage(
        path: '/tmp/model.litertlm',
        inspectedState: const ModelAssetState(
          phase: ModelAssetPhase.ready,
          path: '/tmp/model.litertlm',
        ),
      );
      final service = ModelAssetService(
        storage: storage,
        now: DateTime.now,
      );

      // Act
      final result = await service.check();

      // Assert
      expect(result.phase, ModelAssetPhase.ready);
      expect(storage.inspectedPath, '/tmp/model.litertlm');
    });
  });
}

final class _FakeModelAssetStorage implements ModelAssetStorage {
  _FakeModelAssetStorage({
    required this.path,
    required this.inspectedState,
  });

  final String path;
  final ModelAssetState inspectedState;
  String? inspectedPath;

  @override
  Future<String> modelPath() async => path;

  @override
  Future<String> preparePartialDownload(String modelPath) {
    throw UnimplementedError('download is not used in this test');
  }

  @override
  Future<void> completePartialDownload({
    required String modelPath,
    required String partialPath,
  }) {
    throw UnimplementedError('download is not used in this test');
  }

  @override
  Future<ModelAssetState> inspect(String modelPath) async {
    inspectedPath = modelPath;
    return inspectedState;
  }
}
