import 'package:ai_expense_tracker/features/expenses/expense_controller.dart';
import 'package:ai_expense_tracker/features/expenses/manual_expense_input.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:ai_expense_tracker/shared/theme/app_theme.dart';
import 'package:ai_expense_tracker/shared/widgets/expense_form_controls.dart';
import 'package:ai_expense_tracker/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Bottom-sheet form for manual expense entry.
class ExpenseFormSheet extends ConsumerStatefulWidget {
  /// Creates an expense form.
  const ExpenseFormSheet({super.key});

  @override
  ConsumerState<ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends ConsumerState<ExpenseFormSheet> {
  final _amountController = TextEditingController();
  final _payeeController = TextEditingController();
  final _notesController = TextEditingController();
  final _accountHintController = TextEditingController();
  final _sourceLabelController = TextEditingController();
  final _fundingSourceController = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.food;
  TransactionKind _transactionKind = TransactionKind.expense;
  PaymentMethodKind _paymentMethod = PaymentMethodKind.upi;

  @override
  void dispose() {
    _amountController.dispose();
    _payeeController.dispose();
    _notesController.dispose();
    _accountHintController.dispose();
    _sourceLabelController.dispose();
    _fundingSourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: GlassPanel(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Manual entry',
                style: TextStyle(
                  color: AppTheme.textMuted.withValues(alpha: 0.92),
                  letterSpacing: 1.1,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Log money movement',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Capture spend, people you lent to, and money you borrowed.',
                style: TextStyle(color: AppTheme.textMuted, height: 1.35),
              ),
              const SizedBox(height: 18),
              const FormSectionLabel('Type'),
              const SizedBox(height: 8),
              TransactionKindSelector(
                value: _transactionKind,
                onChanged: (kind) => setState(() => _transactionKind = kind),
              ),
              const SizedBox(height: 18),
              const FormSectionLabel('Amount'),
              const SizedBox(height: 8),
              ShadInput(
                controller: _amountController,
                placeholder: const Text('642'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
              const SizedBox(height: 14),
              const FormSectionLabel('Payee or person'),
              const SizedBox(height: 8),
              ShadInput(
                controller: _payeeController,
                placeholder: Text(
                  _transactionKind == TransactionKind.expense
                      ? 'e.g., Merchant'
                      : 'e.g., Payee',
                ),
              ),
              const SizedBox(height: 14),
              const FormSectionLabel('Category'),
              const SizedBox(height: 8),
              ExpenseCategorySelect(
                value: _category,
                onChanged: (category) => setState(() => _category = category),
              ),
              const SizedBox(height: 14),
              const FormSectionLabel('Payment method'),
              const SizedBox(height: 8),
              PaymentMethodSelect(
                value: _paymentMethod,
                onChanged: (method) => setState(() => _paymentMethod = method),
              ),
              const SizedBox(height: 14),
              const FormSectionLabel('Source label'),
              const SizedBox(height: 8),
              ShadInput(
                controller: _sourceLabelController,
                placeholder: Text(
                  switch (_paymentMethod) {
                    PaymentMethodKind.creditCard => 'HSBC Credit Card •1234',
                    PaymentMethodKind.debitCard => 'HDFC Debit Card •2182',
                    PaymentMethodKind.bankAccount => 'Kotak Account •1044',
                    PaymentMethodKind.upi => 'HDFC UPI · yourname@okhdfc',
                    PaymentMethodKind.cash => 'Cash wallet',
                    PaymentMethodKind.other => 'Optional',
                  },
                ),
              ),
              const SizedBox(height: 14),
              const FormSectionLabel('Funding account'),
              const SizedBox(height: 8),
              ShadInput(
                controller: _fundingSourceController,
                placeholder: const Text('Optional linked account'),
              ),
              const SizedBox(height: 14),
              const FormSectionLabel('Masked account hint'),
              const SizedBox(height: 8),
              ShadInput(
                controller: _accountHintController,
                placeholder: const Text('A/c XX2182'),
              ),
              const SizedBox(height: 14),
              const FormSectionLabel('Notes'),
              const SizedBox(height: 8),
              ShadInput(
                controller: _notesController,
                placeholder: const Text('Optional'),
              ),
              const SizedBox(height: 20),
              ShadButton(
                onPressed: _save,
                leading: const Icon(LucideIcons.plus),
                child: Text(
                  _transactionKind == TransactionKind.expense
                      ? 'Save expense'
                      : 'Save entry',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final input = parseManualExpenseInput(
      amountText: _amountController.text,
      payeeText: _payeeController.text,
      category: _category,
      transactionKind: _transactionKind,
      paymentMethod: _paymentMethod,
      notesText: _notesController.text,
      accountHintText: _accountHintController.text,
      sourceLabelText: _sourceLabelController.text,
      fundingSourceLabelText: _fundingSourceController.text,
    );
    if (input == null) return;
    await ref
        .read(expenseControllerProvider.notifier)
        .addManual(
          amount: input.amount,
          payee: input.payee,
          category: input.category,
          transactionKind: input.transactionKind,
          paymentMethod: input.paymentMethod,
          occurredAt: ref.read(nowProvider)(),
          notes: input.notes,
          accountHint: input.accountHint,
          sourceLabel: input.sourceLabel,
          fundingSourceLabel: input.fundingSourceLabel,
        );
    if (mounted) Navigator.of(context).pop();
  }
}
