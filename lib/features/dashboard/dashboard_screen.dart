import 'package:ai_expense_tracker/features/dashboard/dashboard_summary.dart';
import 'package:ai_expense_tracker/features/expenses/expense_controller.dart';
import 'package:ai_expense_tracker/features/model_asset/model_asset_controller.dart';
import 'package:ai_expense_tracker/features/settings/budget_controller.dart';
import 'package:ai_expense_tracker/features/sms_suggestions/sms_suggestions_controller.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/formatters.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:ai_expense_tracker/shared/theme/app_theme.dart';
import 'package:ai_expense_tracker/shared/widgets/category_pill.dart';
import 'package:ai_expense_tracker/shared/widgets/directional_amount.dart';
import 'package:ai_expense_tracker/shared/widgets/glass_panel.dart';
import 'package:ai_expense_tracker/shared/widgets/payment_method_pill.dart';
import 'package:ai_expense_tracker/shared/widgets/transaction_kind_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphic/graphic.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// First screen: calm, useful monthly overview.
class DashboardScreen extends ConsumerWidget {
  /// Creates the dashboard.
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expenseControllerProvider);
    final suggestionsAsync = ref.watch(smsSuggestionsControllerProvider);
    final modelAsync = ref.watch(modelAssetControllerProvider);
    return expensesAsync.when(
      loading: () => const Center(child: ShadProgress()),
      error: (error, stackTrace) => _ErrorState(message: error.toString()),
      data: (expenses) {
        final month = ref.watch(nowProvider)();
        final summary = computeDashboardSummary(
          expenses: expenses,
          month: month,
          elapsedDays: month.day,
        );
        final pending = suggestionsAsync.asData?.value.length ?? 0;

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(expenseControllerProvider.notifier).reload();
            await ref.read(smsSuggestionsControllerProvider.notifier).reload();
            await ref.read(modelAssetControllerProvider.notifier).check();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              _HeroCard(
                total: summary.totalSpend,
                month: summary.month,
                pending: pending,
                lentTotal: summary.totalLent,
                borrowedTotal: summary.totalBorrowed,
                onReviewSms: () => context.push('/sms'),
                onOpenReports: () => context.go('/reports'),
              ),
              const SizedBox(height: 18),
              if (pending > 0)
                _ReminderBanner(
                  icon: LucideIcons.messageSquare,
                  title:
                      '$pending SMS suggestion${pending == 1 ? '' : 's'} waiting',
                  message: 'Review them before they hit your monthly totals.',
                  action: 'Review',
                  onPressed: () => context.push('/sms'),
                ),
              modelAsync.when(
                data: (model) => model.isReady
                    ? const SizedBox.shrink()
                    : _ReminderBanner(
                        icon: LucideIcons.bot,
                        title: 'Gemma model not ready',
                        message: 'Download once for private on-device parsing.',
                        action: 'Download',
                        onPressed: () => context.push('/model'),
                      ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _MetricPanel(
                      label: 'Transactions',
                      value: summary.spendEntries.length.toString(),
                      accent: AppTheme.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricPanel(
                      label: 'Avg spend',
                      value: inrFormat.format(summary.averageDailySpend),
                      accent: AppTheme.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MetricPanel(
                      label: 'Lent out',
                      value: inrFormat.format(summary.totalLent),
                      accent: AppTheme.amber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricPanel(
                      label: 'Borrowed',
                      value: inrFormat.format(summary.totalBorrowed),
                      accent: AppTheme.sky,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SourceBreakdown(entries: summary.rankedSources),
              const SizedBox(height: 14),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category flow',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 210,
                      child: _CategoryChart(
                        categoryTotals: summary.categoryTotals,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _RecentList(expenses: summary.monthExpenses.take(5).toList()),
            ],
          ),
        );
      },
    );
  }
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard({
    required this.total,
    required this.month,
    required this.pending,
    required this.lentTotal,
    required this.borrowedTotal,
    required this.onReviewSms,
    required this.onOpenReports,
  });

  final double total;
  final DateTime month;
  final int pending;
  final double lentTotal;
  final double borrowedTotal;
  final VoidCallback onReviewSms;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref
        .watch(budgetControllerProvider.notifier)
        .getBudgetForMonth(month);
    final progress = computeBudgetProgress(
      totalSpend: total,
      budget: budget,
      safeColor: AppTheme.turquoise,
      warningColor: AppTheme.amber,
      dangerColor: AppTheme.coral,
    );

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthFormat.format(month),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            inrFormat.format(total),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 42,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () {
              final monthKey = ref
                  .read(budgetControllerProvider.notifier)
                  .getMonthKey(month);
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _BudgetEditorSheet(
                  initialBudget: budget,
                  monthKey: monthKey,
                  monthLabel: monthFormat.format(month),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            progress.isOver
                                ? LucideIcons.circleAlert
                                : LucideIcons.wallet,
                            size: 16,
                            color: progress.color,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            progress.isOver
                                ? 'Over budget limit'
                                : 'Monthly Budget Progress',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: progress.isOver
                                  ? AppTheme.coral
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${(progress.percent * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: progress.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress.percent,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation(progress.color),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        progress.isOver
                            ? '${inrFormat.format(progress.difference)} over limit!'
                            : '${inrFormat.format(budget - total)} left',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: progress.isOver
                              ? AppTheme.coral
                              : AppTheme.turquoise,
                        ),
                      ),
                      Text(
                        'of ${inrFormat.format(budget)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ShadButton(
                  onPressed: onReviewSms,
                  leading: const Icon(LucideIcons.messageSquare),
                  child: const Text('Review SMS'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ShadButton.secondary(
                  onPressed: onOpenReports,
                  leading: const Icon(LucideIcons.chartNoAxesColumn),
                  child: const Text('Reports'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetEditorSheet extends StatefulWidget {
  const _BudgetEditorSheet({
    required this.initialBudget,
    required this.monthKey,
    required this.monthLabel,
  });

  final double initialBudget;
  final String monthKey;
  final String monthLabel;

  @override
  State<_BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends State<_BudgetEditorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialBudget.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Consumer(
        builder: (context, ref, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Budget for ${widget.monthLabel}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Changing this updates budget for this and future months. Previous months remain unchanged.',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              Row(
                children: [
                  const Text(
                    '₹',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.turquoise,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ShadInput(
                      controller: _controller,
                      placeholder: const Text('40000'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ShadButton(
                      onPressed: () async {
                        final val = double.tryParse(_controller.text);
                        if (val != null && val >= 0) {
                          final navigator = Navigator.of(context);
                          await ref
                              .read(budgetControllerProvider.notifier)
                              .setBudget(widget.monthKey, val);
                          navigator.pop();
                        }
                      },
                      child: const Text('Save Budget'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReminderBanner extends StatelessWidget {
  const _ReminderBanner({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        borderColor: AppTheme.accent.withValues(alpha: 0.24),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: const TextStyle(color: Color(0xA3FFFFFF)),
                  ),
                ],
              ),
            ),
            ShadButton.secondary(
              onPressed: onPressed,
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceBreakdown extends StatelessWidget {
  const _SourceBreakdown({required this.entries});

  final List<MapEntry<String, double>> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final peak = entries.first.value;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top sources',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'See which cards and accounts are carrying this month.',
            style: TextStyle(color: AppTheme.textMuted, height: 1.35),
          ),
          const SizedBox(height: 14),
          for (final entry in entries.take(4)) ...[
            _SourceRow(
              label: entry.key,
              value: entry.value,
              peak: peak,
            ),
            if (entry != entries.take(4).last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.label,
    required this.value,
    required this.peak,
  });

  final String label;
  final double value;
  final double peak;

  @override
  Widget build(BuildContext context) {
    final progress = peak <= 0 ? 0.0 : (value / peak).clamp(0, 1).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              inrFormat.format(value),
              style: const TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
          ),
        ),
      ],
    );
  }
}

class _CategoryChart extends StatelessWidget {
  const _CategoryChart({required this.categoryTotals});

  final Map<ExpenseCategory, double> categoryTotals;

  @override
  Widget build(BuildContext context) {
    final colorsByCategory = {
      for (final entry in categoryTotals.entries)
        entry.key.label: Color(entry.key.accentValue),
    };
    final data = categoryTotals.entries
        .map(
          (entry) => {
            'category': entry.key.label,
            'amount': entry.value,
          },
        )
        .toList();

    if (data.isEmpty) {
      return const Center(
        child: Text(
          'No confirmed expenses this month.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Chart<Map<String, Object>>(
      data: data,
      variables: {
        'category': Variable(
          accessor: (map) => map['category']! as String,
        ),
        'amount': Variable(
          accessor: (map) => map['amount']! as num,
          scale: LinearScale(min: 0),
        ),
      },
      transforms: [
        Proportion(variable: 'amount', as: 'percent'),
      ],
      marks: [
        IntervalMark(
          position: Varset('percent') / Varset('category'),
          color: ColorEncode(
            encoder: (tuple) => colorsByCategory[tuple['category'] as String]!,
          ),
          modifiers: [StackModifier()],
          label: LabelEncode(
            encoder: (tuple) {
              final percent = (tuple['percent'] as num) * 100;
              if (percent < 4) return Label('');
              return Label(
                '${percent.toStringAsFixed(0)}%',
                LabelStyle(
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  align: Alignment.center,
                ),
              );
            },
          ),
        ),
      ],
      coord: PolarCoord(
        transposed: true,
        dimCount: 1,
        startRadius: 0.45,
      ),
      tooltip: TooltipGuide(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        radius: const Radius.circular(8),
        elevation: 4,
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      selections: {'tap': PointSelection(dim: Dim.x)},
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              ShadButton.ghost(
                onPressed: () => context.go('/expenses'),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: Text(
                  'Confirm SMS suggestions or add your first expense.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ),
            )
          else
            for (final expense in expenses)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => context.push('/expenses/${expense.id}'),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                expense.payee,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            DirectionalAmount(
                              amount: expense.amount,
                              kind: expense.transactionKind,
                              size: DirectionalAmountSize.small,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Flexible(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  TransactionKindPill(expense.transactionKind),
                                  CategoryPill(expense.category),
                                  PaymentMethodPill(expense.paymentMethod),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassPanel(
        child: Text(message, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }
}
