import 'dart:convert';

import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the native Gemma gateway.
final gemmaGatewayProvider = Provider<GemmaGateway>((ref) {
  return const GemmaBridge();
});

/// Provides current native Gemma diagnostics.
final gemmaDiagnosticsProvider = FutureProvider<GemmaRuntimeDiagnostics>((ref) {
  return ref.watch(gemmaGatewayProvider).diagnostics();
});

/// Contract for native Gemma model operations.
abstract interface class GemmaGateway {
  /// Loads the model at [path] in the native process.
  Future<bool> loadModel(String path);

  /// Requests strict JSON parsing for a bank/UPI SMS body.
  Future<ParsedExpense?> parseSms(String smsBody);

  /// Returns current native model diagnostics for live verification.
  Future<GemmaRuntimeDiagnostics> diagnostics();
}

/// Native LiteRT-LM runtime metrics exposed for live testing.
final class GemmaRuntimeDiagnostics {
  /// Creates diagnostics.
  const GemmaRuntimeDiagnostics({
    required this.loaded,
    this.backend,
    this.modelPath,
    this.initTimeMs,
    this.lastParseTimeMs,
    this.timeToFirstTokenSeconds,
    this.decodeTokensPerSecond,
    this.lastError,
  });

  /// Whether a native engine is initialized.
  final bool loaded;

  /// Active backend, such as GPU or CPU.
  final String? backend;

  /// Currently loaded model path.
  final String? modelPath;

  /// Engine initialization time in milliseconds.
  final int? initTimeMs;

  /// Last SMS parse duration in milliseconds.
  final int? lastParseTimeMs;

  /// Time-to-first-token from the last parse.
  final double? timeToFirstTokenSeconds;

  /// Decode throughput from the last parse.
  final double? decodeTokensPerSecond;

  /// Last recorded native error, if any.
  final String? lastError;

  /// Deserializes diagnostics from platform data.
  factory GemmaRuntimeDiagnostics.fromMap(Map<dynamic, dynamic>? map) {
    return GemmaRuntimeDiagnostics(
      loaded: map?['loaded'] as bool? ?? false,
      backend: map?['backend'] as String?,
      modelPath: map?['modelPath'] as String?,
      initTimeMs: map?['initTimeMs'] as int?,
      lastParseTimeMs: map?['lastParseTimeMs'] as int?,
      timeToFirstTokenSeconds: (map?['timeToFirstTokenSeconds'] as num?)
          ?.toDouble(),
      decodeTokensPerSecond: (map?['decodeTokensPerSecond'] as num?)
          ?.toDouble(),
      lastError: map?['lastError'] as String?,
    );
  }
}

/// Method-channel facade for the Android LiteRT-LM bridge.
final class GemmaBridge implements GemmaGateway {
  /// Creates a bridge.
  const GemmaBridge();

  static const _channel = MethodChannel('ai_expense_tracker/gemma');

  /// Loads the model at [path] in the native process.
  @override
  Future<bool> loadModel(String path) async {
    final result = await _channel.invokeMethod<bool>('loadModel', {
      'path': path,
    });
    return result ?? false;
  }

  /// Requests strict JSON parsing for a bank/UPI SMS body.
  @override
  Future<ParsedExpense?> parseSms(String smsBody) async {
    final response = await _channel.invokeMethod<String>(
      'parseSms',
      {'smsBody': smsBody},
    );
    if (response == null || response.trim().isEmpty) return null;
    return _parsedExpenseFromModelJson(
      jsonDecode(response) as Map<String, dynamic>,
    );
  }

  /// Returns current native model diagnostics for live verification.
  @override
  Future<GemmaRuntimeDiagnostics> diagnostics() async {
    final response = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'diagnostics',
    );
    return GemmaRuntimeDiagnostics.fromMap(response);
  }
}

ParsedExpense _parsedExpenseFromModelJson(Map<String, dynamic> json) {
  final amount = _numberFrom(json['amount']);
  final date =
      DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now();
  final payee =
      _stringFrom(json['payee']) ??
      _stringFrom(json['sourceLabel']) ??
      _stringFrom(json['fundingSourceLabel']) ??
      'Unknown';
  return ParsedExpense(
    amount: amount,
    currency: _stringFrom(json['currency']) ?? 'INR',
    date: date,
    payee: payee,
    category: ExpenseCategory.fromLabel(_stringFrom(json['category'])),
    transactionKind: TransactionKind.fromValue(
      _stringFrom(json['transactionKind']),
    ),
    paymentMethod: PaymentMethodKind.fromValue(
      _stringFrom(json['paymentMethod']),
    ),
    confidence: _numberFrom(
      json['confidence'],
      fallback: 0.5,
    ).clamp(0, 1).toDouble(),
    reason: _stringFrom(json['reason']) ?? 'Parsed on device.',
    isPersonLike: json['isPersonLike'] == true,
    accountHint: _stringFrom(json['accountHint']),
    sourceLabel: _stringFrom(json['sourceLabel']),
    fundingSourceLabel: _stringFrom(json['fundingSourceLabel']),
  );
}

double _numberFrom(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ??
        fallback;
  }
  return fallback;
}

String? _stringFrom(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return text;
}
