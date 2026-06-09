import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/widgets/expense_form_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  group('TransactionKindSelector', () {
    testWidgets('renders all transaction kind labels and reports selection', (
      tester,
    ) async {
      // Arrange
      TransactionKind? selected;

      // Act
      await tester.pumpWidget(
        ShadApp(
          home: Scaffold(
            body: TransactionKindSelector(
              value: TransactionKind.expense,
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.tap(find.text(TransactionKind.lent.label));

      // Assert
      expect(find.text(TransactionKind.expense.label), findsOneWidget);
      expect(find.text(TransactionKind.lent.label), findsOneWidget);
      expect(find.text(TransactionKind.borrowed.label), findsOneWidget);
      expect(selected, TransactionKind.lent);
    });
  });

  group('FormSectionLabel', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormSectionLabel('Test Label'),
          ),
        ),
      );
      expect(find.text('Test Label'), findsOneWidget);
    });
  });

  group('ExpenseCategorySelect', () {
    testWidgets('renders selected category and changes it', (tester) async {
      ExpenseCategory? selected;

      await tester.pumpWidget(
        ShadApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ExpenseCategorySelect(
                  value: ExpenseCategory.food,
                  onChanged: (value) => selected = value,
                );
              },
            ),
          ),
        ),
      );

      // Verify food is visible
      expect(find.text('Food'), findsOneWidget);

      // Open the dropdown selection
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      // Tap 'Bills' option
      await tester.tap(find.text('Bills').last);
      await tester.pumpAndSettle();

      expect(selected, ExpenseCategory.bills);
    });
  });

  group('PaymentMethodSelect', () {
    testWidgets('renders selected payment method and changes it', (tester) async {
      PaymentMethodKind? selected;

      await tester.pumpWidget(
        ShadApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return PaymentMethodSelect(
                  value: PaymentMethodKind.upi,
                  onChanged: (value) => selected = value,
                );
              },
            ),
          ),
        ),
      );

      // Verify UPI is visible
      expect(find.text('UPI'), findsOneWidget);

      // Open the dropdown
      await tester.tap(find.text('UPI'));
      await tester.pumpAndSettle();

      // Tap 'Cash' option
      await tester.tap(find.text('Cash').last);
      await tester.pumpAndSettle();

      expect(selected, PaymentMethodKind.cash);
    });
  });

  group('FormToggleChip', () {
    testWidgets('triggers onTap and visualizes selection', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormToggleChip(
              label: 'Chip',
              selected: true,
              color: Colors.blue,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Chip'), findsOneWidget);
      await tester.tap(find.text('Chip'));
      expect(tapped, isTrue);
    });
  });
}

