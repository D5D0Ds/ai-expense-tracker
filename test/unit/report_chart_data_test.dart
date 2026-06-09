import 'package:ai_expense_tracker/features/reports/report_chart_data.dart';
import 'package:ai_expense_tracker/features/reports/report_trend_data.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('report chart data', () {
    test('builds contiguous monthly trend data including zero months', () {
      // Arrange
      final trend = _trendData(
        monthlyTotals: {
          DateTime(2026, 4): 100,
          DateTime(2026, 6): 300,
        },
        dateWindow: TrendDateWindow(
          DateTime(2026, 4, 1),
          DateTime(2026, 6, 30),
        ),
      );

      // Act
      final data = buildMonthlyTrendChartData(trend);

      // Assert
      expect(data, [
        {ReportChartFields.label: 'Apr', ReportChartFields.amount: 100.0},
        {ReportChartFields.label: 'May', ReportChartFields.amount: 0.0},
        {ReportChartFields.label: 'Jun', ReportChartFields.amount: 300.0},
      ]);
    });

    test('ranks category and payment method totals descending', () {
      // Arrange
      final trend = _trendData(
        categoryTotals: {
          ExpenseCategory.food: 200,
          ExpenseCategory.travel: 500,
        },
        paymentMethodTotals: {
          PaymentMethodKind.upi: 50,
          PaymentMethodKind.creditCard: 125,
        },
      );

      // Act
      final categoryData = buildCategoryChartData(trend);
      final paymentData = buildPaymentMethodChartData(trend);

      // Assert
      expect(categoryData.first[ReportChartFields.label], 'Travel');
      expect(categoryData.first[ReportChartFields.amount], 500);
      expect(paymentData.first[ReportChartFields.label], 'Credit card');
      expect(paymentData.first[ReportChartFields.amount], 125);
    });

    test('limits and compacts account chart data', () {
      // Arrange
      final trend = _trendData(
        accountTotals: {
          'Very Long Account Name': 500,
          'Short': 400,
          'Ignored': 300,
        },
      );

      // Act
      final data = buildAccountChartData(trend, limit: 2);

      // Assert
      expect(data, [
        {
          ReportChartFields.label: 'Very Long Ac..',
          ReportChartFields.amount: 500.0,
        },
        {ReportChartFields.label: 'Short', ReportChartFields.amount: 400.0},
      ]);
    });

    test('detects whether chart data has positive amounts', () {
      // Arrange
      final emptyData = [
        {ReportChartFields.label: 'Apr', ReportChartFields.amount: 0.0},
      ];
      final positiveData = [
        {ReportChartFields.label: 'Apr', ReportChartFields.amount: 1.0},
      ];

      // Act / Assert
      expect(hasPositiveAmount(emptyData), isFalse);
      expect(hasPositiveAmount(positiveData), isTrue);
    });

    test('maps chart labels to accent values with safe fallbacks', () {
      // Act / Assert
      expect(
        categoryAccentForChartLabel('Food'),
        ExpenseCategory.food.accentValue,
      );
      expect(
        categoryAccentForChartLabel('Unknown category'),
        ExpenseCategory.other.accentValue,
      );
      expect(
        paymentMethodAccentForChartLabel('UPI'),
        PaymentMethodKind.upi.accentValue,
      );
      expect(
        paymentMethodAccentForChartLabel('Unknown method'),
        PaymentMethodKind.other.accentValue,
      );
    });
  });
}

TrendData _trendData({
  Map<DateTime, double> monthlyTotals = const {},
  Map<ExpenseCategory, double> categoryTotals = const {},
  Map<PaymentMethodKind, double> paymentMethodTotals = const {},
  Map<String, double> accountTotals = const {},
  TrendDateWindow? dateWindow,
}) {
  return TrendData(
    monthlyTotals: monthlyTotals,
    categoryTotals: categoryTotals,
    paymentMethodTotals: paymentMethodTotals,
    accountTotals: accountTotals,
    filteredExpenses: const [],
    totalSpend: 0,
    totalLent: 0,
    totalBorrowed: 0,
    dateWindow:
        dateWindow ??
        TrendDateWindow(
          DateTime(2026, 1, 1),
          DateTime(2026, 1, 31),
        ),
  );
}
