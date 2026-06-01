import 'package:ai_expense_tracker/features/expenses/expense_controller.dart';
import 'package:ai_expense_tracker/features/expenses/expense_form_sheet.dart';
import 'package:ai_expense_tracker/features/expenses/expense_list_summary.dart';
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

/// Searchable expense list.
class ExpenseListScreen extends ConsumerStatefulWidget {
  /// Creates the expense list.
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  final _searchController = TextEditingController();
  ExpenseCategory? _category;
  TransactionKind? _transactionKind;
  PaymentMethodKind? _paymentMethod;
  String? _sourceLabel;
  bool _filtersExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expenseControllerProvider);
    return expensesAsync.when(
      loading: () => const Center(child: ShadProgress()),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (expenses) {
        final summary = computeExpenseListSummary(
          expenses: expenses,
          filter: ExpenseListFilter(
            query: _searchController.text,
            category: _category,
            transactionKind: _transactionKind,
            paymentMethod: _paymentMethod,
            sourceLabel: _sourceLabel,
          ),
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ledger',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                  ),
                ),
                ShadIconButton(
                  icon: const Icon(LucideIcons.plus),
                  onPressed: () => _showForm(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Filter cards, accounts, UPI rails, and money between people.',
              style: TextStyle(color: AppTheme.textMuted, height: 1.35),
            ),
            const SizedBox(height: 14),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShadInput(
                    controller: _searchController,
                    placeholder: const Text(
                      'Search payee, category, account, or payment rail',
                    ),
                    leading: const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(LucideIcons.search, size: 18),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryTile(
                          label: 'Outgoing',
                          value: inrFormat.format(summary.outgoingTotal),
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryTile(
                          label: 'Borrowed',
                          value: inrFormat.format(summary.borrowedTotal),
                          color: AppTheme.sky,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () =>
                        setState(() => _filtersExpanded = !_filtersExpanded),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                LucideIcons.slidersHorizontal,
                                size: 16,
                                color: _filtersExpanded
                                    ? AppTheme.turquoise
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Category & Payment Filters',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _filtersExpanded
                                      ? AppTheme.turquoise
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            _filtersExpanded
                                ? LucideIcons.chevronUp
                                : LucideIcons.chevronDown,
                            size: 16,
                            color: AppTheme.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: _filtersExpanded
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              const Divider(color: Color(0x1FFFFFFF)),
                              const SizedBox(height: 12),
                              _FilterSection(
                                title: 'Type',
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _FilterChip(
                                      label: 'All',
                                      selected: _transactionKind == null,
                                      onTap: () => setState(
                                        () => _transactionKind = null,
                                      ),
                                    ),
                                    for (final kind in TransactionKind.values)
                                      _FilterChip(
                                        label: kind.label,
                                        selected: _transactionKind == kind,
                                        color: Color(kind.accentValue),
                                        onTap: () => setState(
                                          () => _transactionKind =
                                              _transactionKind == kind
                                              ? null
                                              : kind,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              _FilterSection(
                                title: 'Category',
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _FilterChip(
                                      label: 'All',
                                      selected: _category == null,
                                      onTap: () =>
                                          setState(() => _category = null),
                                    ),
                                    for (final category
                                        in ExpenseCategory.values)
                                      _FilterChip(
                                        label: category.label,
                                        selected: _category == category,
                                        color: Color(category.accentValue),
                                        onTap: () => setState(
                                          () =>
                                              _category = _category == category
                                              ? null
                                              : category,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              _FilterSection(
                                title: 'Payment rail',
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _FilterChip(
                                      label: 'All',
                                      selected: _paymentMethod == null,
                                      onTap: () =>
                                          setState(() => _paymentMethod = null),
                                    ),
                                    for (final method
                                        in PaymentMethodKind.values)
                                      _FilterChip(
                                        label: method.label,
                                        selected: _paymentMethod == method,
                                        color: Color(method.accentValue),
                                        onTap: () => setState(
                                          () => _paymentMethod =
                                              _paymentMethod == method
                                              ? null
                                              : method,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (summary.sourceOptions.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _FilterSection(
                                  title: 'Cards & accounts',
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _FilterChip(
                                        label: 'All',
                                        selected: _sourceLabel == null,
                                        onTap: () =>
                                            setState(() => _sourceLabel = null),
                                      ),
                                      for (final source
                                          in summary.sourceOptions)
                                        _FilterChip(
                                          label: source,
                                          selected: _sourceLabel == source,
                                          onTap: () => setState(
                                            () => _sourceLabel =
                                                _sourceLabel == source
                                                ? null
                                                : source,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (summary.filteredExpenses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48, horizontal: 18),
                child: Center(
                  child: Text(
                    'No ledger entries match this view.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else ...[
              Text(
                '${summary.filteredExpenses.length} visible entr${summary.filteredExpenses.length == 1 ? 'y' : 'ies'}',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              for (final expense in summary.filteredExpenses) ...[
                _ExpenseTile(expense: expense),
                const SizedBox(height: 10),
              ],
            ],
          ],
        );
      },
    );
  }

  void _showForm(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExpenseFormSheet(),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: () => context.push('/expenses/${expense.id}'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Color(expense.paymentMethod.accentValue).withValues(
                    alpha: 0.14,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  switch (expense.paymentMethod) {
                    PaymentMethodKind.creditCard => LucideIcons.creditCard,
                    PaymentMethodKind.debitCard => LucideIcons.creditCard,
                    PaymentMethodKind.bankAccount => LucideIcons.fileText,
                    PaymentMethodKind.upi => LucideIcons.messageSquare,
                    PaymentMethodKind.cash => LucideIcons.wallet,
                    PaymentMethodKind.other => LucideIcons.receiptText,
                  },
                  color: Color(expense.paymentMethod.accentValue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.payee,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      expense.fundingSourceLabel ??
                          expense.sourceLabel ??
                          expense.accountHint ??
                          'Routing not set',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              DirectionalAmount(
                amount: expense.amount,
                kind: expense.transactionKind,
                size: DirectionalAmountSize.small,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TransactionKindPill(expense.transactionKind),
              CategoryPill(expense.category),
              PaymentMethodPill(expense.paymentMethod),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            transactionDateFormat.format(expense.occurredAt),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppTheme.accentSoft;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? tint.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? tint.withValues(alpha: 0.42)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? tint : AppTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
