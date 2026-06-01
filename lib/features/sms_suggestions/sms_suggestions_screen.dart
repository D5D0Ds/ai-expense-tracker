import 'package:ai_expense_tracker/features/sms_suggestions/sms_suggestion_edit_input.dart';
import 'package:ai_expense_tracker/features/sms_suggestions/sms_suggestions_controller.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:ai_expense_tracker/shared/platform/permission_gateway.dart';
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
import 'package:shadcn_ui/shadcn_ui.dart';

/// Review queue for parsed SMS suggestions.
class SmsSuggestionsScreen extends ConsumerWidget {
  /// Creates the suggestion screen.
  const SmsSuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(smsSuggestionsControllerProvider);
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(LucideIcons.x),
            onPressed: () => context.pop(),
          ),
          title: const Text('SMS suggestions'),
          actions: [
            IconButton(
              tooltip: 'Sync SMS from phone',
              icon: const Icon(LucideIcons.refreshCw),
              onPressed: () async {
                final status = await ref
                    .read(permissionGatewayProvider)
                    .status(AppPermission.sms);
                if (status != AppPermissionStatus.granted) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please grant SMS access in Settings to sync.',
                        ),
                        backgroundColor: AppTheme.coral,
                      ),
                    );
                  }
                  return;
                }

                final now = ref.read(nowProvider)();
                if (!context.mounted) return;
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: now,
                  initialDateRange: DateTimeRange(
                    start: now.subtract(const Duration(days: 3)),
                    end: now,
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
                  if (!context.mounted) return;
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  try {
                    await ref
                        .read(smsSuggestionsControllerProvider.notifier)
                        .syncInbox(picked.start, picked.end);
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('SMS sync completed successfully!'),
                        backgroundColor: AppTheme.turquoise,
                      ),
                    );
                  } on Object catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Sync failed: $e'),
                        backgroundColor: AppTheme.coral,
                      ),
                    );
                  }
                }
              },
            ),
            IconButton(
              tooltip: 'Inject test SMS',
              icon: const Icon(LucideIcons.messageSquare),
              onPressed: () {
                ref
                    .read(smsSuggestionsControllerProvider.notifier)
                    .injectDemoSms();
              },
            ),
          ],
        ),
        body: suggestionsAsync.when(
          loading: () => const Center(child: ShadProgress()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
          data: (suggestions) {
            if (suggestions.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No pending SMS suggestions.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _SuggestionCard(candidate: suggestions[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _SuggestionCard extends ConsumerWidget {
  const _SuggestionCard({required this.candidate});

  final SmsCandidate candidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsed = candidate.proposedExpense;
    return GlassPanel(
      borderColor: Color(parsed.paymentMethod.accentValue).withValues(
        alpha: 0.32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TransactionKindPill(parsed.transactionKind),
              CategoryPill(parsed.category),
              PaymentMethodPill(parsed.paymentMethod),
              _ConfidencePill(parsed.confidence),
            ],
          ),
          const SizedBox(height: 14),
          DirectionalAmount(
            amount: parsed.amount,
            kind: parsed.transactionKind,
            size: DirectionalAmountSize.large,
          ),
          const SizedBox(height: 6),
          Text(
            parsed.payee,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          if (parsed.sourceLabel != null ||
              parsed.fundingSourceLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (parsed.sourceLabel != null) parsed.sourceLabel!,
                if (parsed.fundingSourceLabel != null)
                  parsed.fundingSourceLabel!,
              ].join(' • '),
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            candidate.redactedPreview,
            style: const TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          Text(
            parsed.isPersonLike
                ? 'Looks like a person. Switch between lent, borrowed, or expense before confirming.'
                : candidate.modelReason,
            style: const TextStyle(color: Color(0xD8FFFFFF), fontSize: 13),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ShadButton(
                  onPressed: () {
                    ref
                        .read(smsSuggestionsControllerProvider.notifier)
                        .confirm(candidate);
                  },
                  leading: const Icon(LucideIcons.check),
                  child: const Text('Confirm'),
                ),
              ),
              const SizedBox(width: 8),
              ShadIconButton.secondary(
                icon: const Icon(LucideIcons.pencil),
                onPressed: () => _showEdit(context, candidate),
              ),
              const SizedBox(width: 8),
              ShadIconButton.destructive(
                icon: const Icon(LucideIcons.x),
                onPressed: () {
                  ref
                      .read(smsSuggestionsControllerProvider.notifier)
                      .ignore(candidate);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEdit(BuildContext context, SmsCandidate candidate) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSuggestionSheet(candidate: candidate),
    );
  }
}

class _EditSuggestionSheet extends ConsumerStatefulWidget {
  const _EditSuggestionSheet({required this.candidate});

  final SmsCandidate candidate;

  @override
  ConsumerState<_EditSuggestionSheet> createState() =>
      _EditSuggestionSheetState();
}

class _EditSuggestionSheetState extends ConsumerState<_EditSuggestionSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _payeeController;
  late final TextEditingController _sourceLabelController;
  late final TextEditingController _fundingSourceController;
  late final TextEditingController _accountHintController;
  late ExpenseCategory _category;
  late TransactionKind _transactionKind;
  late PaymentMethodKind _paymentMethod;

  @override
  void initState() {
    super.initState();
    final parsed = widget.candidate.proposedExpense;
    _amountController = TextEditingController(
      text: parsed.amount.toStringAsFixed(0),
    );
    _payeeController = TextEditingController(text: parsed.payee);
    _sourceLabelController = TextEditingController(text: parsed.sourceLabel);
    _fundingSourceController = TextEditingController(
      text: parsed.fundingSourceLabel,
    );
    _accountHintController = TextEditingController(text: parsed.accountHint);
    _category = parsed.category;
    _transactionKind = parsed.transactionKind;
    _paymentMethod = parsed.paymentMethod;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _payeeController.dispose();
    _sourceLabelController.dispose();
    _fundingSourceController.dispose();
    _accountHintController.dispose();
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
              const Text(
                'Edit suggestion',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Fix the type, payment rail, or source labels before confirming.',
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
              const SizedBox(height: 14),
              const _SectionLabel('Payee'),
              const SizedBox(height: 8),
              ShadInput(controller: _payeeController),
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
                placeholder: const Text('Optional'),
              ),
              const SizedBox(height: 14),
              const _SectionLabel('Funding account'),
              const SizedBox(height: 8),
              ShadInput(
                controller: _fundingSourceController,
                placeholder: const Text('Optional'),
              ),
              const SizedBox(height: 14),
              const _SectionLabel('Masked account hint'),
              const SizedBox(height: 8),
              ShadInput(
                controller: _accountHintController,
                placeholder: const Text('Optional'),
              ),
              const SizedBox(height: 20),
              ShadButton(
                onPressed: _save,
                child: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final parsed = parseEditedSuggestion(
      original: widget.candidate.proposedExpense,
      amountText: _amountController.text,
      payeeText: _payeeController.text,
      category: _category,
      transactionKind: _transactionKind,
      paymentMethod: _paymentMethod,
      accountHintText: _accountHintController.text,
      sourceLabelText: _sourceLabelController.text,
      fundingSourceLabelText: _fundingSourceController.text,
    );
    if (parsed == null) return;
    await ref
        .read(smsSuggestionsControllerProvider.notifier)
        .edit(widget.candidate, parsed);
    if (mounted) Navigator.of(context).pop();
  }
}

class _ConfidencePill extends StatelessWidget {
  const _ConfidencePill(this.confidence);

  final double confidence;

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 0.75
        ? AppTheme.accent
        : confidence >= 0.6
        ? AppTheme.amber
        : AppTheme.coral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Text(
        '${(confidence * 100).round()}%',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
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
                ? color.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.45)
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
