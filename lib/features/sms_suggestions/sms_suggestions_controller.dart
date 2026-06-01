import 'package:ai_expense_tracker/features/expenses/expense_api.dart';
import 'package:ai_expense_tracker/features/sms_suggestions/gemma_expense_parser.dart';
import 'package:ai_expense_tracker/features/sms_suggestions/sms_candidate_factory.dart';
import 'package:ai_expense_tracker/features/sms_suggestions/sms_candidate_repository.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:ai_expense_tracker/shared/platform/native_sms_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides access to native SMS operations.
final smsGatewayProvider = Provider<SmsGateway>((ref) {
  return const NativeSmsBridge();
});

/// Provides SMS suggestion state.
final smsSuggestionsControllerProvider =
    AsyncNotifierProvider<SmsSuggestionsController, List<SmsCandidate>>(
      SmsSuggestionsController.new,
    );

/// Controls parsing, confirmation, editing, and ignoring SMS suggestions.
final class SmsSuggestionsController extends AsyncNotifier<List<SmsCandidate>> {
  @override
  Future<List<SmsCandidate>> build() async {
    await drainNativeQueue();
    return ref.watch(smsCandidateRepositoryProvider).pending();
  }

  /// Reloads pending suggestions.
  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(smsCandidateRepositoryProvider).pending(),
    );
  }

  /// Drains native SMS queue and parses unseen messages.
  Future<void> drainNativeQueue() async {
    final messages = await ref.read(smsGatewayProvider).drainPending();
    for (final message in messages) {
      await parseAndQueue(
        sender: message.sender,
        body: message.body,
        receivedAt: message.receivedAt,
      );
    }
  }

  /// Parses and queues a raw SMS body.
  Future<void> parseAndQueue({
    required String sender,
    required String body,
    required DateTime receivedAt,
  }) async {
    final hash = smsBodyHash(body);
    final repository = ref.read(smsCandidateRepositoryProvider);
    if (await repository.containsHash(hash)) return;

    final parsed = await ref.read(gemmaExpenseParserProvider).parse(body);
    if (parsed.amount <= 0) return;
    final candidate = buildPendingSmsCandidate(
      id: ref.read(idGeneratorProvider)(),
      sender: sender,
      body: body,
      receivedAt: receivedAt,
      parsed: parsed,
      createdAt: ref.read(nowProvider)(),
    );
    await repository.upsert(candidate);
    await reload();
  }

  /// Inserts a realistic fake SMS for local testing.
  Future<void> injectDemoSms() async {
    const body =
        'HDFC Bank: Rs. 642.00 debited from A/c XX2182 via UPI to SWIGGY on 01-Jun. Ref 881276.';
    await ref.read(smsGatewayProvider).injectFakeSms(body);
    await drainNativeQueue();
    await reload();
  }

  /// Confirms a suggestion and creates an expense.
  Future<void> confirm(SmsCandidate candidate) async {
    await ref
        .read(parsedExpenseConfirmerProvider)
        .confirmParsed(
          parsed: candidate.proposedExpense,
          smsHash: candidate.bodyHash,
        );
    await ref
        .read(smsCandidateRepositoryProvider)
        .upsert(
          candidate.copyWith(status: SmsCandidateStatus.confirmed),
        );
    await ref.read(expenseReloaderProvider).reload();
    await reload();
  }

  /// Saves edited parsed fields and keeps the candidate pending.
  Future<void> edit(SmsCandidate candidate, ParsedExpense parsed) async {
    await ref
        .read(smsCandidateRepositoryProvider)
        .upsert(
          candidate.copyWith(
            status: SmsCandidateStatus.pending,
            proposedExpense: parsed,
            modelReason: 'Edited by user after on-device parsing.',
          ),
        );
    await reload();
  }

  /// Ignores a suggestion.
  Future<void> ignore(SmsCandidate candidate) async {
    await ref
        .read(smsCandidateRepositoryProvider)
        .upsert(
          candidate.copyWith(status: SmsCandidateStatus.ignored),
        );
    await reload();
  }

  /// Syncs phone SMS inbox within a given date range.
  Future<void> syncInbox(DateTime start, DateTime end) async {
    state = const AsyncValue.loading();
    try {
      final messages = await ref
          .read(smsGatewayProvider)
          .queryInbox(
            start,
            end,
          );
      for (final message in messages) {
        await parseAndQueue(
          sender: message.sender,
          body: message.body,
          receivedAt: message.receivedAt,
        );
      }
      await reload();
    } on Object catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
