import 'package:ai_expense_tracker/shared/platform/native_sms_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
