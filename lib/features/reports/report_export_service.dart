import 'dart:io';

import 'package:ai_expense_tracker/features/expenses/expense_api.dart';
import 'package:ai_expense_tracker/features/reports/report_documents.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Provides report export operations.
final reportExportServiceProvider = Provider<ReportExportService>((ref) {
  return ReportExportService(
    expenseExportMarker: ref.watch(expenseExportMarkerProvider),
    fileStore: ref.watch(reportFileStoreProvider),
    shareGateway: ref.watch(reportShareGatewayProvider),
  );
});

/// Provides report file destinations.
final reportFileStoreProvider = Provider<ReportFileStore>((ref) {
  return const AppDocumentsReportFileStore();
});

/// Provides report sharing.
final reportShareGatewayProvider = Provider<ReportShareGateway>((ref) {
  return const SharePlusReportShareGateway();
});

/// Resolves report file destinations.
abstract interface class ReportFileStore {
  /// Returns a writable file for a report month and extension.
  Future<File> reportFile(DateTime month, String extension);
}

/// Shares exported report files.
abstract interface class ReportShareGateway {
  /// Shares [file] through the platform.
  Future<void> share(File file);
}

/// Stores reports under the app documents directory.
final class AppDocumentsReportFileStore implements ReportFileStore {
  /// Creates a report file store.
  const AppDocumentsReportFileStore();

  @override
  Future<File> reportFile(DateTime month, String extension) async {
    final directory = await getApplicationDocumentsDirectory();
    final reports = Directory(p.join(directory.path, 'reports'));
    await reports.create(recursive: true);
    final filename =
        'expense-report-${month.year}-${month.month.toString().padLeft(2, '0')}.$extension';
    return File(p.join(reports.path, filename));
  }
}

/// Shares reports using `share_plus`.
final class SharePlusReportShareGateway implements ReportShareGateway {
  /// Creates a share gateway.
  const SharePlusReportShareGateway();

  @override
  Future<void> share(File file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Expense report',
        text: 'Monthly expense report from AI Expense Tracker.',
      ),
    );
  }
}

/// Creates local Excel and PDF reports, then delegates sharing.
final class ReportExportService {
  /// Creates a report service.
  const ReportExportService({
    required ExpenseExportMarker expenseExportMarker,
    required ReportFileStore fileStore,
    required ReportShareGateway shareGateway,
  })  : _expenseExportMarker = expenseExportMarker,
        _fileStore = fileStore,
        _shareGateway = shareGateway;

  final ExpenseExportMarker _expenseExportMarker;
  final ReportFileStore _fileStore;
  final ReportShareGateway _shareGateway;

  /// Creates an Excel file for [expenses].
  Future<File> exportExcel(List<Expense> expenses, DateTime month) =>
      _exportAndShare(
        expenses,
        month,
        'xlsx',
        (file) async => file.writeAsBytes(
          buildExcelReportBytes(expenses),
          flush: true,
        ),
      );

  /// Creates a PDF file for [expenses].
  Future<File> exportPdf(List<Expense> expenses, DateTime month) =>
      _exportAndShare(
        expenses,
        month,
        'pdf',
        (file) async => file.writeAsBytes(
          await buildPdfReportBytes(expenses, month),
          flush: true,
        ),
      );

  Future<File> _exportAndShare(
    List<Expense> expenses,
    DateTime month,
    String extension,
    Future<File> Function(File file) writeFile,
  ) async {
    final file = await _fileStore.reportFile(month, extension);
    await writeFile(file);
    await _expenseExportMarker.markExported(
      expenses.map((expense) => expense.id),
    );
    return file;
  }

  /// Shares a report file through Android share sheet.
  Future<void> share(File file) async {
    await _shareGateway.share(file);
  }
}
