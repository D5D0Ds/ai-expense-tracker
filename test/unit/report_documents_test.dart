import 'package:ai_expense_tracker/features/reports/report_documents.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('report documents', () {
    test(
      'buildExcelReportBytes includes expected headers and expense data',
      () {
        // Arrange
        final expenses = [_expense()];

        // Act
        final bytes = buildExcelReportBytes(expenses);
        final excel = Excel.decodeBytes(bytes);
        final sheet = excel['Expenses'];

        // Assert
        expect(sheet.rows.first[0]?.value.toString(), 'Date');
        expect(sheet.rows.first[1]?.value.toString(), 'Entry');
        expect(sheet.rows[1][2]?.value.toString(), 'Swiggy');
        expect(sheet.rows[1][3]?.value.toString(), 'Food');
        expect(sheet.rows[1][7]?.value.toString(), '250');
      },
    );

    test('buildPdfReportBytes creates a non-empty PDF document', () async {
      // Arrange
      final expenses = [_expense()];
      final month = DateTime(2026, 6);

      // Act
      final bytes = await buildPdfReportBytes(expenses, month);

      // Assert
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });
}

Expense _expense() {
  return Expense(
    id: 'expense-1',
    amount: 250,
    currency: 'INR',
    occurredAt: DateTime(2026, 6, 1, 10),
    payee: 'Swiggy',
    category: ExpenseCategory.food,
    source: ExpenseSource.manual,
    transactionKind: TransactionKind.expense,
    paymentMethod: PaymentMethodKind.upi,
    sourceLabel: 'Bank SMS',
    fundingSourceLabel: 'HDFC',
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );
}
