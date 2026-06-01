import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/widgets/tinted_pill.dart';
import 'package:flutter/material.dart';

/// Compact chip describing whether an entry is spend, lent, or borrowed.
class TransactionKindPill extends StatelessWidget {
  /// Creates a transaction kind pill.
  const TransactionKindPill(this.kind, {super.key});

  /// Transaction kind to display.
  final TransactionKind kind;

  @override
  Widget build(BuildContext context) {
    return TintedPill(
      label: kind.label,
      color: Color(kind.accentValue),
    );
  }
}
