import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/widgets/category_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders category label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CategoryPill(ExpenseCategory.food)),
      ),
    );

    expect(find.text('Food'), findsOneWidget);
  });
}
