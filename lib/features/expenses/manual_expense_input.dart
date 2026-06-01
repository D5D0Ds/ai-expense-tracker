import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/text_normalization.dart';

/// Parsed manual expense form input.
final class ManualExpenseInput {
  /// Creates parsed manual expense input.
  const ManualExpenseInput({
    required this.amount,
    required this.payee,
    required this.category,
    required this.transactionKind,
    required this.paymentMethod,
    this.notes,
    this.accountHint,
    this.sourceLabel,
    this.fundingSourceLabel,
  });

  /// Parsed amount.
  final double amount;

  /// Trimmed payee.
  final String payee;

  /// Selected category.
  final ExpenseCategory category;

  /// Selected transaction type.
  final TransactionKind transactionKind;

  /// Selected payment method.
  final PaymentMethodKind paymentMethod;

  /// Optional notes.
  final String? notes;

  /// Optional account hint.
  final String? accountHint;

  /// Optional source label.
  final String? sourceLabel;

  /// Optional funding source label.
  final String? fundingSourceLabel;
}

/// Parses manual expense form fields.
ManualExpenseInput? parseManualExpenseInput({
  required String amountText,
  required String payeeText,
  required ExpenseCategory category,
  required TransactionKind transactionKind,
  required PaymentMethodKind paymentMethod,
  String? notesText,
  String? accountHintText,
  String? sourceLabelText,
  String? fundingSourceLabelText,
}) {
  final amount = double.tryParse(amountText.trim());
  final payee = payeeText.trim();
  if (amount == null || amount <= 0 || payee.isEmpty) return null;

  return ManualExpenseInput(
    amount: amount,
    payee: payee,
    category: category,
    transactionKind: transactionKind,
    paymentMethod: paymentMethod,
    notes: trimToNull(notesText),
    accountHint: trimToNull(accountHintText),
    sourceLabel: trimToNull(sourceLabelText),
    fundingSourceLabel: trimToNull(fundingSourceLabelText),
  );
}
