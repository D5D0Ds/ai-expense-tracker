import 'dart:io';

import 'package:ai_expense_tracker/features/model_asset/model_asset_config.dart';
import 'package:ai_expense_tracker/features/model_asset/model_asset_service.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(CancelToken());
    registerFallbackValue((int count, int total) {});
  });

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

    test('AppSupportModelAssetStorage modelPath returns application support subpath', () async {
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final tempDir = await Directory.systemTemp.createTemp('path_provider_test');
      addTearDown(() => tempDir.delete(recursive: true));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationSupportDirectory') {
          return tempDir.path;
        }
        return null;
      });

      const storage = AppSupportModelAssetStorage();
      final path = await storage.modelPath();

      expect(path, contains(tempDir.path));
      expect(path, contains('models'));
      expect(path, contains(gemmaModelFilename));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('AppSupportModelAssetStorage preparePartialDownload creates parent and deletes old part file', () async {
      final tempDir = await Directory.systemTemp.createTemp('storage_test');
      addTearDown(() => tempDir.delete(recursive: true));

      final modelPath = '${tempDir.path}/models/gemma.bin';
      final partPath = '$modelPath.part';

      final oldPart = File(partPath);
      await oldPart.parent.create(recursive: true);
      await oldPart.writeAsString('old data');

      const storage = AppSupportModelAssetStorage();
      final resultPath = await storage.preparePartialDownload(modelPath);

      expect(resultPath, partPath);
      expect(await oldPart.exists(), isFalse);
    });

    test('AppSupportModelAssetStorage completePartialDownload deletes existing and renames part file', () async {
      final tempDir = await Directory.systemTemp.createTemp('storage_test');
      addTearDown(() => tempDir.delete(recursive: true));

      final modelPath = '${tempDir.path}/models/gemma.bin';
      final partPath = '$modelPath.part';

      final modelFile = File(modelPath);
      await modelFile.parent.create(recursive: true);
      await modelFile.writeAsString('existing model');

      final partFile = File(partPath);
      await partFile.writeAsString('new downloaded model data');

      const storage = AppSupportModelAssetStorage();
      await storage.completePartialDownload(modelPath: modelPath, partialPath: partPath);

      expect(await partFile.exists(), isFalse);
      expect(await modelFile.exists(), isTrue);
      expect(await modelFile.readAsString(), 'new downloaded model data');
    });

    test('ModelAssetService.download successful download and progress emission', () async {
      final tempDir = await Directory.systemTemp.createTemp('service_download_test');
      addTearDown(() => tempDir.delete(recursive: true));

      final storage = _FakeModelAssetStorage(
        path: '${tempDir.path}/model.bin',
        inspectedState: const ModelAssetState(
          phase: ModelAssetPhase.ready,
          path: '/dummy/model.bin',
        ),
      );

      var currentTime = DateTime(2026, 6, 9, 9, 0, 0);
      final mockDio = MockDio();
      final service = ModelAssetService(
        storage: storage,
        now: () => currentTime,
        dio: mockDio,
      );

      final progressStates = <ModelAssetState>[];

      when(() => mockDio.download(
            any<String>(),
            any<dynamic>(),
            cancelToken: any<CancelToken>(named: 'cancelToken'),
            deleteOnError: any<bool>(named: 'deleteOnError'),
            onReceiveProgress: any<ProgressCallback>(named: 'onReceiveProgress'),
          )).thenAnswer((invocation) async {
        final onReceiveProgress = invocation.namedArguments[#onReceiveProgress] as void Function(int, int)?;

        onReceiveProgress?.call(100, 1000);

        currentTime = currentTime.add(const Duration(milliseconds: 600));
        onReceiveProgress?.call(500, 1000);

        currentTime = currentTime.add(const Duration(milliseconds: 100));
        onReceiveProgress?.call(600, 1000);

        currentTime = currentTime.add(const Duration(milliseconds: 100));
        onReceiveProgress?.call(1000, 1000);

        return Response(requestOptions: RequestOptions(path: ''));
      });

      final finalState = await service.download(
        onProgress: (state) {
          progressStates.add(state);
        },
      );

      expect(finalState.phase, ModelAssetPhase.ready);
      expect(progressStates.length, 2);

      expect(progressStates[0].phase, ModelAssetPhase.downloading);
      expect(progressStates[0].receivedBytes, 500);
      expect(progressStates[0].bytesPerSecond, closeTo(833.33, 0.1));

      expect(progressStates[1].phase, ModelAssetPhase.downloading);
      expect(progressStates[1].receivedBytes, 1000);
    });

    test('ModelAssetService.download fails with DioException', () async {
      final storage = _FakeModelAssetStorage(
        path: '/dummy/model.bin',
        inspectedState: const ModelAssetState(
          phase: ModelAssetPhase.failed,
          path: '/dummy/model.bin',
        ),
      );

      final mockDio = MockDio();
      final service = ModelAssetService(
        storage: storage,
        now: DateTime.now,
        dio: mockDio,
      );

      when(() => mockDio.download(
            any<String>(),
            any<dynamic>(),
            cancelToken: any<CancelToken>(named: 'cancelToken'),
            deleteOnError: any<bool>(named: 'deleteOnError'),
            onReceiveProgress: any<ProgressCallback>(named: 'onReceiveProgress'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        message: 'Connection timed out',
      ));

      final state = await service.download(onProgress: (_) {});
      expect(state.phase, ModelAssetPhase.failed);
      expect(state.message, contains('Connection timed out'));
    });

    test('ModelAssetService.download cancelled with DioException', () async {
      final storage = _FakeModelAssetStorage(
        path: '/dummy/model.bin',
        inspectedState: const ModelAssetState(
          phase: ModelAssetPhase.failed,
          path: '/dummy/model.bin',
        ),
      );

      final mockDio = MockDio();
      final service = ModelAssetService(
        storage: storage,
        now: DateTime.now,
        dio: mockDio,
      );

      when(() => mockDio.download(
            any<String>(),
            any<dynamic>(),
            cancelToken: any<CancelToken>(named: 'cancelToken'),
            deleteOnError: any<bool>(named: 'deleteOnError'),
            onReceiveProgress: any<ProgressCallback>(named: 'onReceiveProgress'),
          )).thenAnswer((invocation) async {
        service.cancel();
        throw DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.cancel,
          error: 'User cancelled download',
        );
      });

      final state = await service.download(onProgress: (_) {});
      expect(state.phase, ModelAssetPhase.cancelled);
      expect(state.message, contains('Download cancelled'));
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
  String? preparedPath;
  bool completed = false;

  @override
  Future<String> modelPath() async => path;

  @override
  Future<String> preparePartialDownload(String modelPath) async {
    preparedPath = modelPath;
    return '$modelPath.part';
  }

  @override
  Future<void> completePartialDownload({
    required String modelPath,
    required String partialPath,
  }) async {
    completed = true;
  }

  @override
  Future<ModelAssetState> inspect(String modelPath) async {
    inspectedPath = modelPath;
    return inspectedState;
  }
}
