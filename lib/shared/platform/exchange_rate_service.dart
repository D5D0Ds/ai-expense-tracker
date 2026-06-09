import 'package:ai_expense_tracker/shared/persistence/app_database.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the exchange rate service.
final exchangeRateServiceProvider = Provider<ExchangeRateService>(
  (ref) => ExchangeRateRepository(database: ref.watch(appDatabaseProvider)),
);

/// Contract for USD→INR exchange rate operations.
abstract interface class ExchangeRateService {
  /// Fetches the latest rate from the network and caches it locally.
  Future<void> fetchLatestRate();

  /// Returns the cached USD→INR rate, or a safe offline fallback.
  double getRate();
}

/// Live implementation backed by open.er-api.com and the Hive settings box.
///
/// Rates are persisted so conversions remain accurate between sessions even
/// when the device is offline.
final class ExchangeRateRepository implements ExchangeRateService {
  /// Creates the repository.
  ExchangeRateRepository({required AppDatabase database, Dio? dio})
      : _settings = database.settings,
        _dio = dio ?? Dio();

  static const _settingsKey = 'usd_to_inr_rate';

  /// Fallback rate used only when no cached rate exists and the network is
  /// unavailable.  The live fetch overwrites this on first successful call.
  static const _offlineFallback = 84.0;

  static const _apiUrl = 'https://open.er-api.com/v6/latest/USD';

  final dynamic _settings; // Box<dynamic>
  final Dio _dio;

  /// Fetches the latest USD→INR rate from the official open.er-api endpoint
  /// and persists it.  Failures are silently swallowed so the app continues
  /// working offline.
  @override
  Future<void> fetchLatestRate() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _apiUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      final rates = response.data?['rates'] as Map<String, dynamic>?;
      final inr = (rates?['INR'] as num?)?.toDouble();
      if (inr != null && inr > 0) {
        await _settings.put(_settingsKey, inr);
      }
    } on DioException catch (_) {
      // Network errors must not crash the app.
    } on Exception catch (_) {
      // Other non-fatal errors (e.g., malformed JSON) must not crash.
    }
  }

  /// Returns the cached USD→INR rate, or [_offlineFallback] if none cached.
  @override
  double getRate() {
    final cached = _settings.get(_settingsKey);
    if (cached is num && cached > 0) return cached.toDouble();
    return _offlineFallback;
  }
}
