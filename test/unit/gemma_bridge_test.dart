import 'dart:convert';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/platform/gemma_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GemmaRuntimeDiagnostics', () {
    test('deserializes complete map correctly', () {
      final map = {
        'loaded': true,
        'backend': 'GPU',
        'modelPath': '/path/to/model',
        'initTimeMs': 120,
        'lastParseTimeMs': 450,
        'timeToFirstTokenSeconds': 0.75,
        'decodeTokensPerSecond': 15.4,
        'lastError': 'no error',
      };

      final diag = GemmaRuntimeDiagnostics.fromMap(map);

      expect(diag.loaded, isTrue);
      expect(diag.backend, 'GPU');
      expect(diag.modelPath, '/path/to/model');
      expect(diag.initTimeMs, 120);
      expect(diag.lastParseTimeMs, 450);
      expect(diag.timeToFirstTokenSeconds, 0.75);
      expect(diag.decodeTokensPerSecond, 15.4);
      expect(diag.lastError, 'no error');
    });

    test('deserializes null/empty map with defaults', () {
      final diag = GemmaRuntimeDiagnostics.fromMap(null);

      expect(diag.loaded, isFalse);
      expect(diag.backend, isNull);
      expect(diag.modelPath, isNull);
      expect(diag.initTimeMs, isNull);
      expect(diag.lastParseTimeMs, isNull);
      expect(diag.timeToFirstTokenSeconds, isNull);
      expect(diag.decodeTokensPerSecond, isNull);
      expect(diag.lastError, isNull);
    });
  });

  group('GemmaBridge', () {
    const channel = MethodChannel('ai_expense_tracker/gemma');
    final log = <MethodCall>[];
    late GemmaBridge bridge;
    dynamic channelResponse;

    setUp(() {
      log.clear();
      bridge = const GemmaBridge();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall);
        return channelResponse;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('loadModel invokes channel and returns bool', () async {
      channelResponse = true;
      final result = await bridge.loadModel('/models/gemma.bin');

      expect(log.length, 1);
      expect(log.first.method, 'loadModel');
      expect(log.first.arguments, {'path': '/models/gemma.bin'});
      expect(result, isTrue);
    });

    test('loadModel returns false if platform returns null', () async {
      channelResponse = null;
      final result = await bridge.loadModel('/models/gemma.bin');
      expect(result, isFalse);
    });

    test('diagnostics invokes channel and returns diagnostics', () async {
      channelResponse = {
        'loaded': true,
        'backend': 'CPU',
      };
      final diag = await bridge.diagnostics();

      expect(log.length, 1);
      expect(log.first.method, 'diagnostics');
      expect(diag.loaded, isTrue);
      expect(diag.backend, 'CPU');
    });

    test('parseSms invokes channel and handles complete response', () async {
      final jsonResponse = {
        'amount': 250.50,
        'currency': 'INR',
        'date': '2026-06-09T09:00:00Z',
        'payee': 'Zomato',
        'category': 'food',
        'transactionKind': 'expense',
        'paymentMethod': 'upi',
        'confidence': 0.95,
        'reason': 'Spent on lunch',
        'isPersonLike': false,
        'accountHint': 'HDFC',
      };

      channelResponse = jsonEncode(jsonResponse);
      final parsed = await bridge.parseSms('debited 250.50 from HDFC to Zomato');

      expect(log.length, 1);
      expect(log.first.method, 'parseSms');
      expect(log.first.arguments, {'smsBody': 'debited 250.50 from HDFC to Zomato'});

      expect(parsed, isNotNull);
      expect(parsed!.amount, 250.50);
      expect(parsed.currency, 'INR');
      expect(parsed.payee, 'Zomato');
      expect(parsed.category, ExpenseCategory.food);
      expect(parsed.transactionKind, TransactionKind.expense);
      expect(parsed.paymentMethod, PaymentMethodKind.upi);
      expect(parsed.confidence, 0.95);
      expect(parsed.reason, 'Spent on lunch');
      expect(parsed.isPersonLike, isFalse);
      expect(parsed.accountHint, 'HDFC');
    });

    test('parseSms returns null for null or empty platform response', () async {
      channelResponse = null;
      var result = await bridge.parseSms('some text');
      expect(result, isNull);

      channelResponse = '  ';
      result = await bridge.parseSms('some text');
      expect(result, isNull);
    });

    test('parseSms fallback payee logic (sourceLabel and fundingSourceLabel)', () async {
      // 1. sourceLabel
      channelResponse = jsonEncode({
        'amount': '100',
        'sourceLabel': 'Amazon Pay',
      });
      var parsed = await bridge.parseSms('test');
      expect(parsed!.payee, 'Amazon Pay');

      // 2. fundingSourceLabel
      channelResponse = jsonEncode({
        'amount': '100',
        'fundingSourceLabel': 'Paytm',
      });
      parsed = await bridge.parseSms('test');
      expect(parsed!.payee, 'Paytm');

      // 3. Fallback when all missing
      channelResponse = jsonEncode({
        'amount': '100',
      });
      parsed = await bridge.parseSms('test');
      expect(parsed!.payee, 'Unknown');
    });

    test('parseSms normalizes numeric string values and clamps confidence', () async {
      channelResponse = jsonEncode({
        'amount': '1,234.56',
        'confidence': 1.5, // should be clamped to 1.0
      });
      var parsed = await bridge.parseSms('test');
      expect(parsed!.amount, 1234.56);
      expect(parsed.confidence, 1.0);

      channelResponse = jsonEncode({
        'amount': 'invalid number',
        'confidence': -0.2, // should be clamped to 0.0
      });
      parsed = await bridge.parseSms('test');
      expect(parsed!.amount, 0.0);
      expect(parsed.confidence, 0.0);

      channelResponse = jsonEncode({
        'amount': null,
        'confidence': null,
      });
      parsed = await bridge.parseSms('test');
      expect(parsed!.amount, 0.0);
      expect(parsed.confidence, 0.5); // default fallback
    });

    test('parseSms filters "null" values as string values', () async {
      channelResponse = jsonEncode({
        'amount': 50,
        'currency': 'null',
        'payee': '  ',
        'reason': 'null',
      });
      final parsed = await bridge.parseSms('test');
      expect(parsed!.currency, 'INR'); // fallback
      expect(parsed.payee, 'Unknown'); // fallback
      expect(parsed.reason, 'Parsed on device.'); // fallback
    });

  });
}
