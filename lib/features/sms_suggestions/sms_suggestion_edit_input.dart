import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/text_normalization.dart';

/// Reason stored after a user edits parsed SMS fields.
const editedSuggestionReason = 'Edited by user before confirmation.';

/// Parses user edits for a pending SMS suggestion.
ParsedExpense? parseEditedSuggestion({
  required ParsedExpense original,
  required String amountText,
  required String payeeText,
  required ExpenseCategory category,
  required TransactionKind transactionKind,
  required PaymentMethodKind paymentMethod,
  String? accountHintText,
  String? sourceLabelText,
  String? fundingSourceLabelText,
}) {
  final amount = double.tryParse(amountText.trim());
  final payee = payeeText.trim();
  if (amount == null || amount <= 0 || payee.isEmpty) return null;

  return original.copyWith(
    amount: amount,
    payee: payee,
    category: category,
    transactionKind: transactionKind,
    paymentMethod: paymentMethod,
    accountHint: trimToNull(accountHintText),
    sourceLabel: trimToNull(sourceLabelText),
    fundingSourceLabel: trimToNull(fundingSourceLabelText),
    reason: editedSuggestionReason,
  );
}
