import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides access to native SMS operations.
final smsGatewayProvider = Provider<SmsGateway>(
  (ref) => NativeSmsBridge(fallbackReceivedAt: ref.watch(nowProvider)),
);

/// Contract for Android SMS queue operations.
abstract interface class SmsGateway {
  /// Drains pending SMS messages captured while the app was closed.
  Future<List<NativeSmsMessage>> drainPending();

  /// Adds a fake SMS into the native queue for local device testing.
  Future<void> injectFakeSms(String body);

  /// Queries the phone's SMS inbox for messages within a date range.
  Future<List<NativeSmsMessage>> queryInbox(DateTime start, DateTime end);

  /// Displays or updates a notification for background inbox sync progress.
  Future<void> showSyncNotification({
    required String title,
    required String message,
    required int progress,
    required int max,
  });

  /// Cancels and removes the active inbox sync notification.
  Future<void> cancelSyncNotification();
}

/// Raw SMS message drained from the native queue.
final class NativeSmsMessage {
  /// Creates a native SMS message.
  const NativeSmsMessage({
    required this.sender,
    required this.body,
    required this.receivedAt,
  });

  /// SMS sender.
  final String sender;

  /// Raw SMS body.
  final String body;

  /// Device received time.
  final DateTime receivedAt;

  /// Deserializes from platform data.
  factory NativeSmsMessage.fromMap(
    Map<dynamic, dynamic> map, {
    required DateTime fallbackReceivedAt,
  }) {
    return NativeSmsMessage(
      sender: map['sender'] as String? ?? 'UNKNOWN',
      body: map['body'] as String? ?? '',
      receivedAt: DateTime.fromMillisecondsSinceEpoch(
        map['receivedAt'] as int? ?? fallbackReceivedAt.millisecondsSinceEpoch,
      ),
    );
  }
}

/// Method-channel facade for Android SMS queue operations.
final class NativeSmsBridge implements SmsGateway {
  /// Creates a bridge.
  const NativeSmsBridge({
    required this.fallbackReceivedAt,
  });

  /// Clock used when platform data omits a received timestamp.
  final DateTime Function() fallbackReceivedAt;

  static const _channel = MethodChannel('ai_expense_tracker/sms');

  /// Drains pending SMS messages captured while the app was closed.
  @override
  Future<List<NativeSmsMessage>> drainPending() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('drainPending');
    return (raw ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map(_messageFromMap)
        .toList();
  }

  /// Adds a fake SMS into the native queue for local device testing.
  @override
  Future<void> injectFakeSms(String body) async {
    await _channel.invokeMethod<void>('injectFakeSms', {'body': body});
  }

  /// Queries the phone's SMS inbox for messages within a date range.
  @override
  Future<List<NativeSmsMessage>> queryInbox(
    DateTime start,
    DateTime end,
  ) async {
    final raw = await _channel.invokeMethod<List<dynamic>>('queryInbox', {
      'startTimestamp': start.millisecondsSinceEpoch,
      'endTimestamp': end.millisecondsSinceEpoch,
    });
    return (raw ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map(_messageFromMap)
        .toList();
  }

  @override
  Future<void> showSyncNotification({
    required String title,
    required String message,
    required int progress,
    required int max,
  }) async {
    await _channel.invokeMethod<void>('showSyncNotification', {
      'title': title,
      'message': message,
      'progress': progress,
      'max': max,
    });
  }

  @override
  Future<void> cancelSyncNotification() async {
    await _channel.invokeMethod<void>('cancelSyncNotification');
  }

  NativeSmsMessage _messageFromMap(Map<dynamic, dynamic> map) {
    return NativeSmsMessage.fromMap(
      map,
      fallbackReceivedAt: fallbackReceivedAt(),
    );
  }
}
