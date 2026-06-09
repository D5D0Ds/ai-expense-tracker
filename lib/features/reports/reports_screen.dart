import 'package:ai_expense_tracker/features/expenses/expense_api.dart';
import 'package:ai_expense_tracker/features/reports/report_chart_data.dart';
import 'package:ai_expense_tracker/features/reports/report_trend_data.dart';
import 'package:ai_expense_tracker/features/reports/reports_controller.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/filter_options.dart';
import 'package:ai_expense_tracker/shared/core/formatters.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:ai_expense_tracker/shared/theme/app_theme.dart';
import 'package:ai_expense_tracker/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphic/graphic.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum _TrendView { trend, categories, paymentMethods, accounts }

/// Enhanced trend analyzer with filters and multi-dimensional breakdowns.
class ReportsScreen extends ConsumerStatefulWidget {
  /// Creates the reports screen.
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _TrendView _activeView = _TrendView.trend;

  @override
  Widget build(BuildContext context) {
    final expenses =
        ref.watch(confirmedExpensesProvider).asData?.value ?? const <Expense>[];
    final filter = ref.watch(trendFilterProvider);
    final trend = computeTrendData(expenses, filter);
    final reportState = ref.watch(reportControllerProvider);
    final now = ref.watch(nowProvider)();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Trends',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
            ),
            Row(
              children: [
                if (reportState.isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accent,
                    ),
                  )
                else ...[
                  IconButton(
                    icon: const Icon(
                      LucideIcons.fileSpreadsheet,
                      size: 22,
                      color: AppTheme.turquoise,
                    ),
                    onPressed: () {
                      ref
                          .read(reportControllerProvider.notifier)
                          .exportExcel(now);
                    },
                    tooltip: 'Export Excel',
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.fileText,
                      size: 22,
                      color: AppTheme.sky,
                    ),
                    onPressed: () {
                      ref
                          .read(reportControllerProvider.notifier)
                          .exportPdf(now);
                    },
                    tooltip: 'Export PDF',
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Analyze spend by month, category, payment rail, and funding source.',
          style: TextStyle(color: AppTheme.textMuted, height: 1.35),
        ),
        const SizedBox(height: 16),

        // Date range + filter chips
        _FilterBar(filter: filter),
        const SizedBox(height: 16),

        // Summary snapshot
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateHeading(
                filter: filter,
                count: trend.filteredExpenses.length,
              ),
              const SizedBox(height: 16),
              Text(
                inrFormat.format(trend.totalSpend),
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SnapshotTile(
                      label: 'Lent',
                      value: inrFormat.format(trend.totalLent),
                      color: AppTheme.amber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SnapshotTile(
                      label: 'Borrowed',
                      value: inrFormat.format(trend.totalBorrowed),
                      color: AppTheme.sky,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // View selector
        _ViewSelector(
          active: _activeView,
          onChanged: (view) => setState(() => _activeView = view),
        ),
        const SizedBox(height: 16),

        // Chart area
        GlassPanel(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _buildChart(trend),
          ),
        ),
      ],
    );
  }

  Widget _buildChart(TrendData trend) {
    return KeyedSubtree(
      key: ValueKey(_activeView),
      child: switch (_activeView) {
        _TrendView.trend => _buildTrendChart(trend),
        _TrendView.categories => _buildCategoryChart(trend),
        _TrendView.paymentMethods => _buildPaymentMethodChart(trend),
        _TrendView.accounts => _buildAccountChart(trend),
      },
    );
  }

  Widget _buildTrendChart(TrendData trend) {
    final data = buildMonthlyTrendChartData(trend);
    if (!hasPositiveAmount(data)) return _emptyChartPlaceholder;

    return SizedBox(
      height: 260,
      child: Chart<Map<String, Object>>(
        data: data,
        variables: {
          ReportChartFields.label: Variable(
            accessor: (map) => map[ReportChartFields.label]! as String,
          ),
          ReportChartFields.amount: Variable(
            accessor: (map) => map[ReportChartFields.amount]! as num,
            scale: LinearScale(min: 0),
          ),
        },
        marks: [
          IntervalMark(
            color: ColorEncode(
              value: AppTheme.blue.withValues(alpha: 0.6),
            ),
          ),
          LineMark(
            shape: ShapeEncode(value: BasicLineShape(smooth: true)),
            color: ColorEncode(value: AppTheme.accent),
            size: SizeEncode(value: 3),
          ),
        ],
        axes: [
          Defaults.horizontalAxis,
          Defaults.verticalAxis,
        ],
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
      ),
    );
  }

  Widget _buildDonutChart({
    required List<Map<String, Object>> data,
    required Color Function(String name) colorMapper,
  }) {
    return SizedBox(
      height: 260,
      child: Chart<Map<String, Object>>(
        data: data,
        variables: {
          ReportChartFields.label: Variable(
            accessor: (map) => map[ReportChartFields.label]! as String,
          ),
          ReportChartFields.amount: Variable(
            accessor: (map) => map[ReportChartFields.amount]! as num,
            scale: LinearScale(min: 0),
          ),
        },
        transforms: [
          Proportion(variable: ReportChartFields.amount, as: 'percent'),
        ],
        marks: [
          IntervalMark(
            position: Varset('percent') / Varset(ReportChartFields.label),
            color: ColorEncode(
              encoder: (tuple) {
                return colorMapper(tuple[ReportChartFields.label] as String);
              },
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
      ),
    );
  }

  Widget _buildCategoryChart(TrendData trend) {
    final data = buildCategoryChartData(trend);
    if (data.isEmpty) return _emptyChartPlaceholder;

    return _buildDonutChart(
      data: data,
      colorMapper: (name) {
        return Color(
          categoryAccentForChartLabel(name),
        ).withValues(alpha: 0.85);
      },
    );
  }

  Widget _buildPaymentMethodChart(TrendData trend) {
    final data = buildPaymentMethodChartData(trend);
    if (data.isEmpty) return _emptyChartPlaceholder;

    return _buildDonutChart(
      data: data,
      colorMapper: (name) {
        return Color(
          paymentMethodAccentForChartLabel(name),
        ).withValues(alpha: 0.85);
      },
    );
  }

  Widget _buildAccountChart(TrendData trend) {
    final data = buildAccountChartData(trend);
    if (data.isEmpty) return _emptyChartPlaceholder;

    return _buildDonutChart(
      data: data,
      colorMapper: (name) {
        final index = data.indexWhere((element) {
          return element[ReportChartFields.label] == name;
        });
        final hue = (index * 137.5) % 360;
        return HSLColor.fromAHSL(0.85, hue, 0.65, 0.6).toColor();
      },
    );
  }
}

class _DateHeading extends StatelessWidget {
  const _DateHeading({required this.filter, required this.count});

  final TrendFilter filter;
  final int count;

  @override
  Widget build(BuildContext context) {
    final startLabel = DateFormat.yMMMd().format(filter.startDate);
    final endLabel = DateFormat.yMMMd().format(filter.endDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date Range',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$startLabel — $endLabel  ·  $count transactions',
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends ConsumerStatefulWidget {
  const _FilterBar({required this.filter});

  final TrendFilter filter;

  @override
  ConsumerState<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends ConsumerState<_FilterBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final filter = widget.filter;
    final now = ref.watch(nowProvider)();
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Custom Date Range Selector Button
          InkWell(
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: now.add(const Duration(days: 365)),
                initialDateRange: DateTimeRange(
                  start: filter.startDate,
                  end: filter.endDate,
                ),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppTheme.turquoise,
                        onPrimary: Colors.black,
                        surface: AppTheme.surface,
                        onSurface: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                ref.read(trendFilterProvider.notifier).filter = filter.copyWith(
                  startDate: picked.start,
                  endDate: picked.end,
                );
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.calendar,
                    size: 18,
                    color: AppTheme.turquoise,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${DateFormat.yMMMd().format(filter.startDate)} — ${DateFormat.yMMMd().format(filter.endDate)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.slidersHorizontal,
                        size: 16,
                        color: _expanded
                            ? AppTheme.turquoise
                            : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Category & Payment Filters',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _expanded
                              ? AppTheme.turquoise
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
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
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Divider(color: Color(0x1FFFFFFF)),
                      const SizedBox(height: 16),

                      // Category filter
                      _FilterRow(
                        icon: LucideIcons.tag,
                        label: 'Category',
                        options: [
                          for (final cat in buildNullableFilterOptions(
                            selected: filter.category,
                            values: ExpenseCategory.values,
                            labelFor: (category) => category.label,
                            accentFor: (category) => category.accentValue,
                          ))
                            _FilterOption(
                              label: cat.label,
                              selected: cat.selected,
                              color: _filterColor(cat),
                              onTap: () =>
                                  ref
                                      .read(trendFilterProvider.notifier)
                                      .filter = filter.copyWith(
                                    category: cat.nextValue,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Payment method filter
                      _FilterRow(
                        icon: LucideIcons.creditCard,
                        label: 'Payment',
                        options: [
                          for (final method in buildNullableFilterOptions(
                            selected: filter.paymentMethod,
                            values: PaymentMethodKind.values,
                            labelFor: (method) => method.label,
                            accentFor: (method) => method.accentValue,
                          ))
                            _FilterOption(
                              label: method.label,
                              selected: method.selected,
                              color: _filterColor(method),
                              onTap: () =>
                                  ref
                                      .read(trendFilterProvider.notifier)
                                      .filter = filter.copyWith(
                                    paymentMethod: method.nextValue,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Transaction kind filter
                      _FilterRow(
                        icon: LucideIcons.arrowLeftRight,
                        label: 'Kind',
                        options: [
                          for (final kind in buildNullableFilterOptions(
                            selected: filter.transactionKind,
                            values: TransactionKind.values,
                            labelFor: (kind) => kind.label,
                            accentFor: (kind) => kind.accentValue,
                          ))
                            _FilterOption(
                              label: kind.label,
                              selected: kind.selected,
                              color: _filterColor(kind),
                              onTap: () =>
                                  ref
                                      .read(trendFilterProvider.notifier)
                                      .filter = filter.copyWith(
                                    transactionKind: kind.nextValue,
                                  ),
                            ),
                        ],
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.icon,
    required this.label,
    required this.options,
  });

  final IconData icon;
  final String label;
  final List<_FilterOption> options;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppTheme.surfaceRaised,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: AppTheme.textMuted),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: options,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Color? _filterColor<T>(SelectableFilterOption<T> option) {
  final accentValue = option.accentValue;
  return accentValue != null ? Color(accentValue) : null;
}

const _emptyChartPlaceholder = SizedBox(
  height: 200,
  child: Center(
    child: Text(
      'No spending in this range.',
      style: TextStyle(color: AppTheme.textMuted),
    ),
  ),
);

class _FilterOption extends StatelessWidget {
  const _FilterOption({
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
    final accent = color ?? AppTheme.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? accent : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewSelector extends StatelessWidget {
  const _ViewSelector({required this.active, required this.onChanged});

  final _TrendView active;
  final ValueChanged<_TrendView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          for (final view in _TrendView.values)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(view),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active == view
                        ? AppTheme.accent.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    switch (view) {
                      _TrendView.trend => 'Trend',
                      _TrendView.categories => 'Categories',
                      _TrendView.paymentMethods => 'Payment',
                      _TrendView.accounts => 'Accounts',
                    },
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active == view
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: active == view
                          ? AppTheme.accent
                          : AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SnapshotTile extends StatelessWidget {
  const _SnapshotTile({
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
