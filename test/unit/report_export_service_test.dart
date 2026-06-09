import 'dart:io';

import 'package:ai_expense_tracker/features/expenses/expense_api.dart';
import 'package:ai_expense_tracker/features/expenses/expense_ports.dart';
import 'package:ai_expense_tracker/features/reports/report_export_service.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportExportService Providers & AppDocumentsReportFileStore', () {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('report_path_test_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('providers resolve instances successfully', () {
      final container = ProviderContainer(
        overrides: [
          // Override expenseExportMarkerProvider with a stub to avoid state errors
          expenseExportMarkerProvider.overrideWithValue(_FakeExpenseExportMarker()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(reportFileStoreProvider), isA<AppDocumentsReportFileStore>());
      expect(container.read(reportShareGatewayProvider), isA<SharePlusReportShareGateway>());
      expect(container.read(reportExportServiceProvider), isA<ReportExportService>());
    });

    test('AppDocumentsReportFileStore resolves file path under temp/reports', () async {
      const fileStore = AppDocumentsReportFileStore();
      final file = await fileStore.reportFile(DateTime(2026, 6), 'pdf');

      expect(file.path, contains('reports/expense-report-2026-06.pdf'));
    });
  });

  group('ReportExportService', () {
    late Directory directory;
    late _FakeExpenseExportMarker exportMarker;
    late _FakeReportShareGateway shareGateway;
    late ReportExportService service;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('report_export_test_');
      exportMarker = _FakeExpenseExportMarker();
      shareGateway = _FakeReportShareGateway();
      service = ReportExportService(
        expenseExportMarker: exportMarker,
        fileStore: _TempReportFileStore(directory),
        shareGateway: shareGateway,
      );
    });

    tearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test(
      'exportExcel writes an xlsx file and marks expenses exported',
      () async {
        // Arrange
        final expenses = [_expense(id: 'expense-1')];
        final month = DateTime(2026, 6);

        // Act
        final file = await service.exportExcel(expenses, month);

        // Assert
        expect(file.path, endsWith('expense-report-2026-06.xlsx'));
        expect(await file.exists(), isTrue);
        expect(await file.length(), greaterThan(0));
        expect(exportMarker.markedIds, ['expense-1']);
      },
    );

    test('exportPdf writes a pdf file and marks expenses exported', () async {
      // Arrange
      final expenses = [_expense(id: 'expense-1')];
      final month = DateTime(2026, 6);

      // Act
      final file = await service.exportPdf(expenses, month);

      // Assert
      expect(file.path, endsWith('expense-report-2026-06.pdf'));
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));
      expect(exportMarker.markedIds, ['expense-1']);
    });

    test('share delegates to the injected share gateway', () async {
      // Arrange
      final file = File('${directory.path}/report.pdf');
      await file.writeAsBytes([1, 2, 3]);

      // Act
      await service.share(file);

      // Assert
      expect(shareGateway.sharedFiles, [file.path]);
    });
  });
}

Expense _expense({required String id}) {
  return Expense(
    id: id,
    amount: 250,
    currency: 'INR',
    occurredAt: DateTime(2026, 6, 1, 10),
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
