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
    return ParsedExpense.fromJson(jsonDecode(response) as Map<String, dynamic>);
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
