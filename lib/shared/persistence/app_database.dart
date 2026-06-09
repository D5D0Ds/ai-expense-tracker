import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Provides the opened local database to repositories.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError('AppDatabase must be overridden during bootstrap.'),
);

/// Hive boxes used by the app.
class AppDatabase {
  AppDatabase._({
    required this.expenses,
    required this.smsCandidates,
    required this.settings,
  });

  /// Confirmed expense box.
  final Box<dynamic> expenses;

  /// SMS suggestion box.
  final Box<dynamic> smsCandidates;

  /// Settings and model metadata box.
  final Box<dynamic> settings;

  static const _keyName = 'hive_aes_key_v1';

  /// Opens encrypted Hive boxes.
  static Future<AppDatabase> open() async {
    await Hive.initFlutter();
    final cipher = HiveAesCipher(await _readOrCreateKey());
    final expenses = await Hive.openBox<dynamic>(
      'expenses',
      encryptionCipher: cipher,
    );
    final smsCandidates = await Hive.openBox<dynamic>(
      'sms_candidates',
      encryptionCipher: cipher,
    );
    final settings = await Hive.openBox<dynamic>(
      'settings',
      encryptionCipher: cipher,
    );

    return AppDatabase._(
      expenses: expenses,
      smsCandidates: smsCandidates,
      settings: settings,
    );
  }

  static Future<List<int>> _readOrCreateKey() async {
    const storage = FlutterSecureStorage();
    final existing = await storage.read(key: _keyName);
    if (existing != null) return base64Decode(existing);

    final random = Random.secure();
    final key = List<int>.generate(32, (_) => random.nextInt(256));
    await storage.write(key: _keyName, value: base64Encode(key));
    return key;
  }
}
