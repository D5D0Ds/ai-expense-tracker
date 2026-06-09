import 'package:ai_expense_tracker/shared/platform/native_sms_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeSmsMessage', () {
    test('fromMap uses platform receivedAt when present', () {
      // Arrange
      final receivedAt = DateTime(2026, 6, 1, 12);

      // Act
      final message = NativeSmsMessage.fromMap(
        {
          'sender': 'HDFC',
          'body': 'debited',
          'receivedAt': receivedAt.millisecondsSinceEpoch,
        },
        fallbackReceivedAt: DateTime(2026, 6, 2),
      );

      // Assert
      expect(message.sender, 'HDFC');
      expect(message.body, 'debited');
      expect(message.receivedAt, receivedAt);
    });

    test('fromMap uses injected fallback when receivedAt is missing', () {
      // Arrange
      final fallback = DateTime(2026, 6, 2, 9);

      // Act
      final message = NativeSmsMessage.fromMap(
        const {
          'body': 'credited',
        },
        fallbackReceivedAt: fallback,
      );

      // Assert
      expect(message.sender, 'UNKNOWN');
      expect(message.body, 'credited');
      expect(message.receivedAt, fallback);
    });
  });

  group('NativeSmsBridge', () {
    const channel = MethodChannel('ai_expense_tracker/sms');
    final log = <MethodCall>[];
    late NativeSmsBridge bridge;

    setUp(() {
      log.clear();
      bridge = NativeSmsBridge(
        fallbackReceivedAt: () => DateTime(2026, 6, 1, 12),
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall);
        if (methodCall.method == 'drainPending') {
          return [
            {
              'sender': 'HDFC',
              'body': 'debited 100',
              'receivedAt': DateTime(2026, 6, 1, 10).millisecondsSinceEpoch,
            }
          ];
        }
        if (methodCall.method == 'queryInbox') {
          return [
            {
              'sender': 'SBI',
              'body': 'credited 500',
              'receivedAt': DateTime(2026, 6, 1, 11).millisecondsSinceEpoch,
            }
          ];
        }
        if (methodCall.method == 'injectFakeSms') {
          return null;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('drainPending invokes method channel and returns deserialized messages', () async {
      final result = await bridge.drainPending();

      expect(log.length, 1);
      expect(log.first.method, 'drainPending');
      expect(result.length, 1);
      expect(result.first.sender, 'HDFC');
      expect(result.first.body, 'debited 100');
    });

    test('injectFakeSms invokes method channel with body parameter', () async {
      await bridge.injectFakeSms('test body');

      expect(log.length, 1);
      expect(log.first.method, 'injectFakeSms');
      expect(log.first.arguments, {'body': 'test body'});
    });

    test('queryInbox invokes method channel with date range arguments', () async {
      final start = DateTime(2026, 6, 1, 9);
      final end = DateTime(2026, 6, 1, 13);
      final result = await bridge.queryInbox(start, end);

      expect(log.length, 1);
      expect(log.first.method, 'queryInbox');
      expect(log.first.arguments, {
        'startTimestamp': start.millisecondsSinceEpoch,
        'endTimestamp': end.millisecondsSinceEpoch,
      });
      expect(result.length, 1);
      expect(result.first.sender, 'SBI');
      expect(result.first.body, 'credited 500');
    });
  });
}
