import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/formatters.dart';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds an Excel report document.
List<int> buildExcelReportBytes(List<Expense> expenses) {
  final excel = Excel.createExcel();
  final sheet = excel['Expenses'];
  sheet.appendRow([
    TextCellValue('Date'),
    TextCellValue('Entry'),
    TextCellValue('Payee'),
    TextCellValue('Category'),
    TextCellValue('Payment'),
    TextCellValue('Source Label'),
    TextCellValue('Funding Source'),
    TextCellValue('Amount'),
    TextCellValue('Source'),
  ]);
  for (final expense in expenses) {
    sheet.appendRow([
      TextCellValue(transactionDateFormat.format(expense.occurredAt)),
      TextCellValue(expense.transactionKind.label),
      TextCellValue(expense.payee),
      TextCellValue(expense.category.label),
      TextCellValue(expense.paymentMethod.label),
      TextCellValue(expense.sourceLabel ?? ''),
      TextCellValue(expense.fundingSourceLabel ?? ''),
      DoubleCellValue(expense.amount),
      TextCellValue(expense.source.name),
    ]);
  }
  return excel.encode() ?? <int>[];
}

/// Builds a PDF report document.
Future<List<int>> buildPdfReportBytes(
  List<Expense> expenses,
  DateTime month,
) async {
  final document = pw.Document();
  final total = expenses.fold<double>(
    0,
    (sum, expense) => sum + expense.amount,
  );
  document.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Text(
          'Expense report - ${monthFormat.format(month)}',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Text('Total: ${inrFormat.format(total)}'),
        pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(
          headers: [
            'Date',
            'Entry',
            'Payee',
            'Category',
            'Payment',
            'Amount',
          ],
          data: expenses
              .map(
                (expense) => [
                  transactionDateFormat.format(expense.occurredAt),
                  expense.transactionKind.label,
                  expense.payee,
                  expense.category.label,
                  expense.paymentMethod.label,
                  inrFormat.format(expense.amount),
                ],
              )
              .toList(),
        ),
      ],
    ),
  );
  return document.save();
}
