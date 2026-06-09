import 'dart:io';

import 'package:ai_expense_tracker/features/expenses/expense_api.dart';
import 'package:ai_expense_tracker/features/reports/report_export_service.dart';
import 'package:ai_expense_tracker/features/reports/reports_controller.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportController', () {
    late Directory directory;
    late _FakeExpenseExportMarker exportMarker;
    late _FakeReportShareGateway shareGateway;
    late _FakeExpenseReloader reloader;
    late ProviderContainer container;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'report_controller_test_',
      );
      exportMarker = _FakeExpenseExportMarker();
      shareGateway = _FakeReportShareGateway();
      reloader = _FakeExpenseReloader();
      final exportService = ReportExportService(
        expenseExportMarker: exportMarker,
        fileStore: _TempReportFileStore(directory),
        shareGateway: shareGateway,
      );
      container = ProviderContainer(
        overrides: [
          confirmedExpensesProvider.overrideWithValue(
            AsyncData([
              _expense(id: 'current', occurredAt: DateTime(2026, 6, 1)),
              _expense(id: 'other', occurredAt: DateTime(2026, 5, 31)),
            ]),
          ),
          reportExportServiceProvider.overrideWithValue(exportService),
          expenseReloaderProvider.overrideWithValue(reloader),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test(
      'exportExcel exposes metadata and exports only the selected month',
      () async {
        // Arrange
        final month = DateTime(2026, 6);

        // Act
        await container
            .read(reportControllerProvider.notifier)
            .exportExcel(month);
        final result = container.read(reportControllerProvider).value;

        // Assert
        expect(result?.format, ReportFormat.excel);
        expect(result?.month, month);
        expect(result?.path, endsWith('expense-report-2026-06.xlsx'));
        expect(exportMarker.markedIds, ['current']);
        expect(shareGateway.sharedFiles.single, result?.path);
        expect(reloader.reloadCount, 1);
      },
    );

    test('exportPdf exposes metadata and exports only the selected month', () async {
      // Arrange
      final month = DateTime(2026, 6);

      // Act
      await container.read(reportControllerProvider.notifier).exportPdf(month);
      final result = container.read(reportControllerProvider).value;

      // Assert
      expect(result?.format, ReportFormat.pdf);
      expect(result?.month, month);
      expect(result?.path, endsWith('expense-report-2026-06.pdf'));
      expect(exportMarker.markedIds, ['current']);
      expect(shareGateway.sharedFiles.single, result?.path);
      expect(reloader.reloadCount, 1);
    });
  });
}

Expense _expense({
  required String id,
  required DateTime occurredAt,
}) {
  return Expense(
    id: id,
    amount: 250,
    currency: 'INR',
    occurredAt: occurredAt,
    payee: 'Swiggy',
    category: ExpenseCategory.food,
    source: ExpenseSource.manual,
    transactionKind: TransactionKind.expense,
    paymentMethod: PaymentMethodKind.upi,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );
}

final class _TempReportFileStore implements ReportFileStore {
  const _TempReportFileStore(this.directory);

  final Directory directory;

  @override
  Future<File> reportFile(DateTime month, String extension) async {
    final reports = Directory('${directory.path}/reports');
    await reports.create(recursive: true);
    final filename =
        'expense-report-${month.year}-${month.month.toString().padLeft(2, '0')}.$extension';
    return File('${reports.path}/$filename');
  }
}

final class _FakeExpenseExportMarker implements ExpenseExportMarker {
  final markedIds = <String>[];

  @override
  Future<void> markExported(Iterable<String> ids) async {
    markedIds.addAll(ids);
  }
}

final class _FakeReportShareGateway implements ReportShareGateway {
  final sharedFiles = <String>[];

  @override
  Future<void> share(File file) async {
    sharedFiles.add(file.path);
  }
}

final class _FakeExpenseReloader implements ExpenseReloader {
  int reloadCount = 0;

  @override
  Future<void> reload() async {
    reloadCount++;
  }
}
