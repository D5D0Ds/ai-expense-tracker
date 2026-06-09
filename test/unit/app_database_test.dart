import 'dart:convert';
import 'dart:io';

import 'package:ai_expense_tracker/shared/persistence/app_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../helpers/fake_app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppDatabase Provider', () {
    test('throws StateError when read directly without bootstrap override', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        () => container.read(appDatabaseProvider),
        throwsA(
          isA<Object>().having(
            (e) => e.toString(),
            'toString',
            contains('AppDatabase must be overridden during bootstrap.'),
          ),
        ),
      );
    });
  });

  group('AppDatabase.open', () {
    const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    late Directory tempDir;
    final secureStorageData = <String, String>{};

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_test_dir');
      secureStorageData.clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (methodCall) async {
        if (methodCall.method == 'getApplicationSupportDirectory') {
          return tempDir.path;
        }
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, (methodCall) async {
        if (methodCall.method == 'read') {
          final args = methodCall.arguments as Map;
          final key = args['key'] as String;
          return secureStorageData[key];
        }
        if (methodCall.method == 'write') {
          final args = methodCall.arguments as Map;
          final key = args['key'] as String;
          final value = args['value'] as String;
          secureStorageData[key] = value;
          return true;
        }
        return null;
      });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, null);
      await Hive.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('opens app database, creates encryption key and executes migration', () async {
      // Act
      final db = await AppDatabase.open();

      // Assert
      expect(db.expenses, isNotNull);
      expect(db.smsCandidates, isNotNull);
      expect(db.settings, isNotNull);

      // Verify secure storage key was created
      expect(secureStorageData.containsKey('hive_aes_key_v1'), isTrue);
    });
  });
}
