import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/platform/exchange_rate_service.dart';
import 'package:ai_expense_tracker/shared/platform/gemma_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides SMS parsing through Gemma, with automatic currency normalisation.
final gemmaExpenseParserProvider = Provider<GemmaExpenseParser>((ref) {
  return GemmaExpenseParser(
    bridge: ref.watch(gemmaGatewayProvider),
    rates: ref.watch(exchangeRateServiceProvider),
  );
});

/// Parses Indian bank and UPI SMS messages into editable expense proposals.
///
/// Foreign-currency amounts (currently USD / `$`) are converted to INR using
/// a live rate fetched by [ExchangeRateService] so no value is ever hardcoded.
final class GemmaExpenseParser {
  /// Creates a parser.
  const GemmaExpenseParser({required GemmaGateway bridge, required ExchangeRateService rates})
      : _bridge = bridge,
        _rates = rates;

  final GemmaGateway _bridge;
  final ExchangeRateService _rates;

  static const _usdSymbols = {'USD', '\$'};

  /// Parses a raw SMS body with the native Gemma runtime.
  ///
  /// If the model reports a USD / `$` amount, it is converted to INR at the
  /// latest cached rate before returning.
  Future<ParsedExpense> parse(String smsBody) async {
    final parsed = await _bridge.parseSms(smsBody);
    if (parsed == null) {
      throw StateError('Gemma did not return a valid SMS parse.');
    }
    if (_usdSymbols.contains(parsed.currency.toUpperCase())) {
      final rate = _rates.getRate();
      return parsed.copyWith(
        amount: parsed.amount * rate,
        currency: 'INR',
        reason: '${parsed.reason} (Converted from USD at ₹$rate per USD.)',
      );
    }
    return parsed;
  }
}
