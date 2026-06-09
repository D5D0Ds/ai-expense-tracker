import 'package:ai_expense_tracker/features/sms_suggestions/sms_suggestion_edit_input.dart';
import 'package:ai_expense_tracker/features/sms_suggestions/sms_suggestions_controller.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:ai_expense_tracker/shared/platform/permission_gateway.dart';
import 'package:ai_expense_tracker/shared/theme/app_theme.dart';
import 'package:ai_expense_tracker/shared/widgets/category_pill.dart';
import 'package:ai_expense_tracker/shared/widgets/directional_amount.dart';
import 'package:ai_expense_tracker/shared/widgets/expense_form_controls.dart';
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
    final syncProgress = ref.watch(smsSyncProgressProvider);
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
                final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
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
                  try {
                    await ref
                        .read(smsSuggestionsControllerProvider.notifier)
                        .syncInbox(picked.start, picked.end);
                    scaffoldMessenger?.showSnackBar(
                      const SnackBar(
                        content: Text('SMS sync completed successfully!'),
                        backgroundColor: AppTheme.turquoise,
                      ),
                    );
                  } on Object catch (e) {
                    scaffoldMessenger?.showSnackBar(
                      SnackBar(
                        content: Text('Sync failed: $e'),
                        backgroundColor: AppTheme.coral,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
        body: suggestionsAsync.when(
          loading: () => const Center(
            child: ShadProgress(),
          ),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
          data: (suggestions) {
            return Column(
              children: [
                if (syncProgress != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: _SmsSyncProgressIndicator(progress: syncProgress),
                  ),
                Expanded(
                  child: suggestions.isEmpty && syncProgress == null
                      ? const Center(
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
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          itemCount: suggestions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _SuggestionCard(candidate: suggestions[index]);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

final class _SmsSyncProgressIndicator extends ConsumerWidget {
  const _SmsSyncProgressIndicator({required this.progress});

  final SmsSyncProgress? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = this.progress;
    final label = progress == null
        ? 'Preparing SMS sync'
        : 'Processed ${progress.processed} / ${progress.total} messages';
    final detail = progress == null
        ? 'Reading inbox'
        : 'Added ${progress.added} suggestions • Skipped ${progress.skipped} • Failed ${progress.failed}';
    final value = progress == null || progress.total == 0
        ? null
        : progress.processed / progress.total;

    return Semantics(
      label: label,
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.refreshCw, size: 16, color: AppTheme.blue),
                    SizedBox(width: 8),
                    Text(
                      'Syncing SMS Inbox',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                ShadButton.ghost(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  onPressed: () {
                    ref.read(smsSuggestionsControllerProvider.notifier).cancelSync();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.coral, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ShadProgress(value: value),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
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
          const SizedBox(height: 16),
          DirectionalAmount(
            amount: parsed.amount,
            kind: parsed.transactionKind,
            size: DirectionalAmountSize.large,
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 12),
          Text(
            candidate.redactedPreview,
            style: const TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          Text(
            parsed.isPersonLike
                ? 'Looks like a person. Switch between lent, borrowed, or expense before confirming.'
                : candidate.modelReason,
            style: const TextStyle(color: Color(0xD8FFFFFF), fontSize: 13),
          ),
          const SizedBox(height: 24),
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
              const SizedBox(height: 24),
              const FormSectionLabel('Type'),
              const SizedBox(height: 8),
              TransactionKindSelector(
                value: _transactionKind,
                onChanged: (kind) => setState(() => _transactionKind = kind),
              ),
              const SizedBox(height: 24),
              const FormSectionLabel('Amount'),
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
              const SizedBox(height: 16),
              const FormSectionLabel('Payee'),
              const SizedBox(height: 8),
              ShadInput(controller: _payeeController),
              const SizedBox(height: 16),
              const FormSectionLabel('Category'),
              const SizedBox(height: 8),
              ExpenseCategorySelect(
                value: _category,
                onChanged: (category) => setState(() => _category = category),
              ),
              const SizedBox(height: 16),
              const FormSectionLabel('Payment method'),
              const SizedBox(height: 8),
              PaymentMethodSelect(
                value: _paymentMethod,
                onChanged: (method) => setState(() => _paymentMethod = method),
              ),
              const SizedBox(height: 16),
              const FormSectionLabel('Source label'),
              const SizedBox(height: 8),
              ShadInput(
                controller: _sourceLabelController,
                placeholder: const Text('Optional'),
              ),
              const SizedBox(height: 16),
              const FormSectionLabel('Funding account'),
              const SizedBox(height: 8),
              ShadInput(
                controller: _fundingSourceController,
                placeholder: const Text('Optional'),
              ),
              const SizedBox(height: 16),
              const FormSectionLabel('Masked account hint'),
              const SizedBox(height: 8),
              ShadInput(
                controller: _accountHintController,
                placeholder: const Text('Optional'),
              ),
              const SizedBox(height: 24),
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
