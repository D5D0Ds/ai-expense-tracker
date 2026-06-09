import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Compact label used above expense form controls.
final class FormSectionLabel extends StatelessWidget {
  /// Creates a section label.
  const FormSectionLabel(this.label, {super.key});

  /// Label text.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Toggle group for transaction kind selection.
final class TransactionKindSelector extends StatelessWidget {
  /// Creates a transaction kind selector.
  const TransactionKindSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Selected transaction kind.
  final TransactionKind value;

  /// Called when the user selects a transaction kind.
  final ValueChanged<TransactionKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final kind in TransactionKind.values)
          FormToggleChip(
            label: kind.label,
            selected: value == kind,
            color: Color(kind.accentValue),
            onTap: () => onChanged(kind),
          ),
      ],
    );
  }
}

/// Category selector for expense forms.
final class ExpenseCategorySelect extends StatelessWidget {
  /// Creates a category selector.
  const ExpenseCategorySelect({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Selected category.
  final ExpenseCategory value;

  /// Called when the category changes.
  final ValueChanged<ExpenseCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return ShadSelect<ExpenseCategory>(
      initialValue: value,
      options: ExpenseCategory.values
          .map(
            (category) => ShadOption(
              value: category,
              child: Text(category.label),
            ),
          )
          .toList(),
      selectedOptionBuilder: (context, value) => Text(value.label),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

/// Payment method selector for expense forms.
final class PaymentMethodSelect extends StatelessWidget {
  /// Creates a payment method selector.
  const PaymentMethodSelect({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Selected payment method.
  final PaymentMethodKind value;

  /// Called when the payment method changes.
  final ValueChanged<PaymentMethodKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return ShadSelect<PaymentMethodKind>(
      initialValue: value,
      options: PaymentMethodKind.values
          .map(
            (method) => ShadOption(
              value: method,
              child: Text(method.label),
            ),
          )
          .toList(),
      selectedOptionBuilder: (context, value) => Text(value.label),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

/// Pill toggle used by form selectors.
final class FormToggleChip extends StatelessWidget {
  /// Creates a form toggle chip.
  const FormToggleChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    super.key,
  });

  /// Chip label.
  final String label;

  /// Whether the chip is selected.
  final bool selected;

  /// Accent color.
  final Color color;

  /// Called when tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : AppTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
