import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/widgets/tinted_pill.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Compact chip describing the payment method or rail.
class PaymentMethodPill extends StatelessWidget {
  /// Creates a payment method pill.
  const PaymentMethodPill(this.paymentMethod, {super.key});

  /// Payment method to display.
  final PaymentMethodKind paymentMethod;

  @override
  Widget build(BuildContext context) {
    return TintedPill(
      label: paymentMethod.label,
      color: Color(paymentMethod.accentValue),
      icon: switch (paymentMethod) {
        PaymentMethodKind.creditCard => LucideIcons.creditCard,
        PaymentMethodKind.debitCard => LucideIcons.creditCard,
        PaymentMethodKind.bankAccount => LucideIcons.fileText,
        PaymentMethodKind.upi => LucideIcons.messageSquare,
        PaymentMethodKind.cash => LucideIcons.wallet,
        PaymentMethodKind.other => LucideIcons.receiptText,
      },
    );
  }
}
