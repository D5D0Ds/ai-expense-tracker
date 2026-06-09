import 'package:ai_expense_tracker/features/expenses/expense_controller.dart';
import 'package:ai_expense_tracker/features/expenses/expense_form_sheet.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/formatters.dart';
import 'package:ai_expense_tracker/shared/theme/app_theme.dart';
import 'package:ai_expense_tracker/shared/widgets/category_pill.dart';
import 'package:ai_expense_tracker/shared/widgets/directional_amount.dart';
import 'package:ai_expense_tracker/shared/widgets/glass_panel.dart';
import 'package:ai_expense_tracker/shared/widgets/payment_method_pill.dart';
import 'package:ai_expense_tracker/shared/widgets/transaction_kind_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Transaction detail screen.
class ExpenseDetailScreen extends ConsumerWidget {
  /// Creates a detail screen.
  const ExpenseDetailScreen({required this.id, super.key});

  /// Expense id.
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseAsync = ref.watch(expenseByIdProvider(id));
    return AppBackdrop(
      child: expenseAsync.when(
        loading: () => const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: ShadProgress()),
        ),
        error: (error, stackTrace) => Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: Text(error.toString())),
        ),
        data: (expense) {
          if (expense == null) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => context.pop(),
                ),
              ),
              body: const Center(child: Text('Expense not found')),
            );
          }
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () => context.pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(LucideIcons.pencil),
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => ExpenseFormSheet(expense: expense),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(LucideIcons.trash2),
                  onPressed: () async {
                    await ref.read(expenseControllerProvider.notifier).delete(id);
                    if (context.mounted) context.pop();
                  },
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TransactionKindPill(expense.transactionKind),
                          CategoryPill(expense.category),
                          PaymentMethodPill(expense.paymentMethod),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        transactionDateFormat.format(expense.occurredAt),
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DirectionalAmount(
                        amount: expense.amount,
                        kind: expense.transactionKind,
                        size: DirectionalAmountSize.hero,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        expense.payee,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        expense.source == ExpenseSource.sms
                            ? 'SMS Transaction'
                            : 'Manual Entry',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Routing',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _Line('Entry', expense.transactionKind.label),
                      _Line('Created via', expense.source.name.toUpperCase()),
                      _Line('Payment', expense.paymentMethod.label),
                      if (expense.sourceLabel != null)
                        _Line('Source label', expense.sourceLabel!),
                      if (expense.fundingSourceLabel != null)
                        _Line('Funding', expense.fundingSourceLabel!),
                      if (expense.accountHint != null)
                        _Line('Masked hint', expense.accountHint!),
                      if (expense.confidence != null)
                        _Line(
                          'Confidence',
                          '${(expense.confidence! * 100).round()}%',
                        ),
                      if (expense.reason != null)
                        _Line('Reason', expense.reason!),
                      if (expense.notes != null) _Line('Notes', expense.notes!),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(color: Colors.white54)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
