import 'package:ai_expense_tracker/features/reports/report_trend_data.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:intl/intl.dart';

/// Chart row keys used by report charts.
final class ReportChartFields {
  const ReportChartFields._();

  /// Label field.
  static const label = 'label';

  /// Amount field.
  static const amount = 'amount';
}

/// Builds a month-by-month series for the trend chart.
List<Map<String, Object>> buildMonthlyTrendChartData(TrendData trend) {
  final data = <Map<String, Object>>[];
  final window = trend.dateWindow;
  var cursor = DateTime(window.start.year, window.start.month);
  final end = DateTime(window.end.year, window.end.month);

  while (!cursor.isAfter(end)) {
    data.add({
      ReportChartFields.label: DateFormat.MMM().format(cursor),
      ReportChartFields.amount: trend.monthlyTotals[cursor] ?? 0.0,
    });
    cursor = DateTime(cursor.year, cursor.month + 1);
  }

  return data;
}

/// Builds category totals for a donut chart.
List<Map<String, Object>> buildCategoryChartData(TrendData trend) {
  return _rankedChartData(
    trend.categoryTotals,
    labelFor: (category) => category.label,
  );
}

/// Builds payment method totals for a donut chart.
List<Map<String, Object>> buildPaymentMethodChartData(TrendData trend) {
  return _rankedChartData(
    trend.paymentMethodTotals,
    labelFor: (method) => method.label,
  );
}

/// Builds account totals for a donut chart.
List<Map<String, Object>> buildAccountChartData(
  TrendData trend, {
  int limit = 8,
}) {
  final entries = trend.accountTotals.entries.toList()
    ..sort((left, right) => right.value.compareTo(left.value));
  return entries
      .take(limit)
      .map(
        (entry) => {
          ReportChartFields.label: _compactAccountLabel(entry.key),
          ReportChartFields.amount: entry.value,
        },
      )
      .toList();
}

/// Whether any chart row has a positive amount.
bool hasPositiveAmount(List<Map<String, Object>> data) {
  return data.any((row) => (row[ReportChartFields.amount]! as num) > 0);
}

/// Returns a category accent value for a chart label.
int categoryAccentForChartLabel(String label) {
  return ExpenseCategory.values
      .firstWhere(
        (category) => category.label == label,
        orElse: () => ExpenseCategory.other,
      )
      .accentValue;
}

/// Returns a payment-method accent value for a chart label.
int paymentMethodAccentForChartLabel(String label) {
  return PaymentMethodKind.values
      .firstWhere(
        (method) => method.label == label,
        orElse: () => PaymentMethodKind.other,
      )
      .accentValue;
}

List<Map<String, Object>> _rankedChartData<T>(
  Map<T, double> totals, {
  required String Function(T key) labelFor,
}) {
  final entries = totals.entries.toList()
    ..sort((left, right) => right.value.compareTo(left.value));
  return entries
      .map(
        (entry) => {
          ReportChartFields.label: labelFor(entry.key),
          ReportChartFields.amount: entry.value,
        },
      )
      .toList();
}

String _compactAccountLabel(String label) {
  return label.length > 14 ? '${label.substring(0, 12)}..' : label;
}
