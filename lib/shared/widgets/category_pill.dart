import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/widgets/tinted_pill.dart';
import 'package:flutter/material.dart';

/// Compact category label with its calm accent swatch.
class CategoryPill extends StatelessWidget {
  /// Creates a category pill.
  const CategoryPill(this.category, {super.key});

  /// Category to display.
  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    return TintedPill(
      label: category.label,
      color: Color(category.accentValue),
    );
  }
}
