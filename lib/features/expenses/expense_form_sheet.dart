import 'package:ai_expense_tracker/features/expenses/expense_controller.dart';
import 'package:ai_expense_tracker/features/expenses/manual_expense_input.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:ai_expense_tracker/shared/theme/app_theme.dart';
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
              const _SectionLabel('Type'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in TransactionKind.values)
                    _ToggleChip(
                      label: kind.label,
                      selected: _transactionKind == kind,
                      color: Color(kind.accentValue),
                      onTap: () => setState(() => _transactionKind = kind),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const _SectionLabel('Amount'),
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
              const _SectionLabel('Payee or person'),
              const SizedBox(height: 8),
              ShadInput(
                controller: _payeeController,
                placeholder: Text(
                  _transactionKind == TransactionKind.expense
                      ? 'Swiggy'
                      : 'Rahul Sharma',
                ),
              ),
              const SizedBox(height: 14),
              const _SectionLabel('Category'),
              const SizedBox(height: 8),
              ShadSelect<ExpenseCategory>(
                initialValue: _category,
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
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 14),
              const _SectionLabel('Payment method'),
              const SizedBox(height: 8),
              ShadSelect<PaymentMethodKind>(
                initialValue: _paymentMethod,
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
                  if (value != null) setState(() => _paymentMethod = value);
                },
              ),
              const SizedBox(height: 14),
              const _SectionLabel('Source label'),
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
              const _SectionLabel('Funding account'),
              const SizedBox(height: 8),
              ShadInput(
                controller: _fundingSourceController,
                placeholder: const Text('Optional linked account'),
              ),
              const SizedBox(height: 14),
              const _SectionLabel('Masked account hint'),
              const SizedBox(height: 8),
              ShadInput(
                controller: _accountHintController,
                placeholder: const Text('A/c XX2182'),
              ),
              const SizedBox(height: 14),
              const _SectionLabel('Notes'),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

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

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
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
