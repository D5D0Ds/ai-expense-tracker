import 'package:ai_expense_tracker/features/expenses/expense_api.dart';
import 'package:ai_expense_tracker/features/reports/report_export_service.dart';
import 'package:ai_expense_tracker/features/reports/report_trend_data.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Trend analyzer filter notifier.
final class TrendFilterNotifier extends Notifier<TrendFilter> {
  @override
  TrendFilter build() {
    final now = ref.watch(nowProvider)();
    return TrendFilter(
      startDate: DateTime(now.year, now.month - 5, 1),
      endDate: DateTime(
        now.year,
        now.month + 1,
        1,
      ).subtract(const Duration(days: 1)),
    );
  }

  /// Current filter value.
  TrendFilter get filter => state;

  /// Replaces the current filter.
  set filter(TrendFilter value) => state = value;
}

/// Trend analyzer filter state.
final trendFilterProvider = NotifierProvider<TrendFilterNotifier, TrendFilter>(
  TrendFilterNotifier.new,
);

/// Current monthly report state.
final reportControllerProvider =
    AsyncNotifierProvider<ReportController, ExportedReport?>(
      ReportController.new,
    );

/// Exported report metadata exposed to the UI.
final class ExportedReport {
  /// Creates exported report metadata.
  const ExportedReport({
    required this.path,
    required this.month,
    required this.format,
  });

  /// Local report path.
  final String path;

  /// Report month.
  final DateTime month;

  /// Export format.
  final ReportFormat format;
}

/// Supported report export formats.
enum ReportFormat {
  /// Excel workbook.
  excel,

  /// PDF document.
  pdf,
}

/// Controls monthly report exports.
final class ReportController extends AsyncNotifier<ExportedReport?> {
  @override
  Future<ExportedReport?> build() async => null;

  /// Exports current month to Excel and shares it.
  Future<void> exportExcel(DateTime month) async {
    await _export(month, ReportFormat.excel);
  }

  /// Exports current month to PDF and shares it.
  Future<void> exportPdf(DateTime month) async {
    await _export(month, ReportFormat.pdf);
  }

  Future<void> _export(DateTime month, ReportFormat format) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final expenses = _expensesForMonth(month);
      final exportService = ref.read(reportExportServiceProvider);
      final file = switch (format) {
        ReportFormat.excel => await exportService.exportExcel(expenses, month),
        ReportFormat.pdf => await exportService.exportPdf(expenses, month),
      };
      await exportService.share(file);
      // Only mark exported after the share succeeds so a cancellation or
      // failure does not leave the data state permanently incorrect.
      await exportService.markExported(
        expenses.map((expense) => expense.id),
      );
      await ref.read(expenseReloaderProvider).reload();
      return ExportedReport(
        path: file.path,
        month: month,
        format: format,
      );
    });
  }

  List<Expense> _expensesForMonth(DateTime month) {
    final expenses =
        ref.read(confirmedExpensesProvider).asData?.value ?? const <Expense>[];
    return expenses
        .where(
          (expense) =>
              expense.occurredAt.year == month.year &&
              expense.occurredAt.month == month.month,
        )
        .toList();
  }
}
