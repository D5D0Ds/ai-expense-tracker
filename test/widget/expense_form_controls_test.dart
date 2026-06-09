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
}
