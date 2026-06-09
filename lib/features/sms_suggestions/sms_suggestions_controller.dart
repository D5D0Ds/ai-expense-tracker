import 'dart:async';

import 'package:ai_expense_tracker/features/expenses/expense_api.dart';
import 'package:ai_expense_tracker/features/sms_suggestions/gemma_expense_parser.dart';
import 'package:ai_expense_tracker/features/sms_suggestions/sms_candidate_factory.dart';
import 'package:ai_expense_tracker/features/sms_suggestions/sms_candidate_repository.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:ai_expense_tracker/shared/platform/native_sms_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides SMS suggestion state.
final smsSuggestionsControllerProvider =
    AsyncNotifierProvider<SmsSuggestionsController, List<SmsCandidate>>(
      SmsSuggestionsController.new,
    );

/// Current manual SMS inbox sync progress, when a sync is active.
final smsSyncProgressProvider =
    NotifierProvider<SmsSyncProgressController, SmsSyncProgress?>(
      SmsSyncProgressController.new,
    );

/// Count of messages processed during a manual SMS inbox sync.
final class SmsSyncProgress {
  /// Creates sync progress.
  const SmsSyncProgress({
    required this.processed,
    required this.total,
    required this.added,
    required this.skipped,
    required this.failed,
  });

  /// Number of inbox messages already processed.
  final int processed;

  /// Total inbox messages selected for parsing.
  final int total;

  /// Number of pending suggestions created.
  final int added;

  /// Number of messages ignored because they were duplicate or not expenses.
  final int skipped;

  /// Number of messages that Gemma failed to parse.
  final int failed;

  /// Creates an initial progress value.
  factory SmsSyncProgress.initial({required int total}) {
    return SmsSyncProgress(
      processed: 0,
      total: total,
      added: 0,
      skipped: 0,
      failed: 0,
    );
  }
}

/// Stores manual SMS inbox sync progress.
final class SmsSyncProgressController extends Notifier<SmsSyncProgress?> {
  @override
  SmsSyncProgress? build() => null;
}

/// Controls parsing, confirmation, editing, and ignoring SMS suggestions.
final class SmsSuggestionsController extends AsyncNotifier<List<SmsCandidate>> {
  bool _syncCancelled = false;

  @override
  Future<List<SmsCandidate>> build() async {
    await drainNativeQueue();
    return ref.watch(smsCandidateRepositoryProvider).pending();
  }

  /// Cancels the active SMS inbox sync.
  void cancelSync() {
    _syncCancelled = true;
    ref.read(smsGatewayProvider).cancelSyncNotification();
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
    await _parseAndQueueAll(messages);
  }

  /// Parses and queues a raw SMS body.
  Future<void> parseAndQueue({
    required String sender,
    required String body,
    required DateTime receivedAt,
  }) async {
    await _parseAndQueue(
      sender: sender,
      body: body,
      receivedAt: receivedAt,
      refreshAfterUpsert: true,
    );
  }

  Future<_SmsQueueResult> _parseAndQueue({
    required String sender,
    required String body,
    required DateTime receivedAt,
    required bool refreshAfterUpsert,
  }) async {
    final hash = smsBodyHash(body);
    final repository = ref.read(smsCandidateRepositoryProvider);
    if (await repository.containsHash(hash)) return _SmsQueueResult.skipped;

    final parsed = await ref.read(gemmaExpenseParserProvider).parse(body);
    if (parsed.amount <= 0) return _SmsQueueResult.skipped;
    final candidate = buildPendingSmsCandidate(
      id: ref.read(idGeneratorProvider)(),
      sender: sender,
      body: body,
      receivedAt: receivedAt,
      parsed: parsed,
      createdAt: ref.read(nowProvider)(),
    );
    await repository.upsert(candidate);
    if (refreshAfterUpsert) {
      await reload();
    }
    return _SmsQueueResult.added;
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
    _syncCancelled = false;
    final progressController = ref.read(smsSyncProgressProvider.notifier);
    progressController.state = SmsSyncProgress.initial(total: 0);
    try {
      final messages = await ref
          .read(smsGatewayProvider)
          .queryInbox(
            start,
            end,
          );
      if (_syncCancelled) return;
      progressController.state = SmsSyncProgress.initial(total: messages.length);
      await _parseAndQueueAll(
        messages,
        refreshAfterEachUpsert: true,
        continueOnParseError: true,
        onProgress: (summary) {
          progressController.state = SmsSyncProgress(
            processed: summary.processed,
            total: messages.length,
            added: summary.added,
            skipped: summary.skipped,
            failed: summary.failed,
          );

          unawaited(ref.read(smsGatewayProvider).showSyncNotification(
            title: 'Syncing SMS inbox...',
            message: 'Processed ${summary.processed}/${messages.length} messages (${summary.added} suggestions added)',
            progress: summary.processed,
            max: messages.length,
          ));
        },
      );
    } on Object catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      progressController.state = null;
      if (_syncCancelled) {
        await ref.read(smsGatewayProvider).showSyncNotification(
          title: 'SMS Sync cancelled',
          message: 'Sync was stopped by user.',
          progress: 100,
          max: 100,
        );
      } else {
        await ref.read(smsGatewayProvider).showSyncNotification(
          title: 'SMS Sync complete',
          message: 'Inbox messages processed successfully.',
          progress: 100,
          max: 100,
        );
      }
      unawaited(Future.delayed(const Duration(seconds: 3), () {
        ref.read(smsGatewayProvider).cancelSyncNotification();
      }));
    }
  }

  Future<void> _parseAndQueueAll(
    List<NativeSmsMessage> messages, {
    bool refreshAfterEachUpsert = true,
    bool continueOnParseError = false,
    void Function(_SmsSyncSummary summary)? onProgress,
  }) async {
    var summary = const _SmsSyncSummary();
    for (final message in messages) {
      if (_syncCancelled) {
        break;
      }
      try {
        final result = await _parseAndQueue(
          sender: message.sender,
          body: message.body,
          receivedAt: message.receivedAt,
          refreshAfterUpsert: refreshAfterEachUpsert,
        );
        summary = summary.after(result);
      } on Object {
        if (!continueOnParseError) rethrow;
        summary = summary.after(_SmsQueueResult.failed);
      } finally {
        onProgress?.call(summary);
      }
    }
  }
}

enum _SmsQueueResult { added, skipped, failed }

final class _SmsSyncSummary {
  const _SmsSyncSummary({
    this.processed = 0,
    this.added = 0,
    this.skipped = 0,
    this.failed = 0,
  });

  final int processed;
  final int added;
  final int skipped;
  final int failed;

  _SmsSyncSummary after(_SmsQueueResult result) {
    return _SmsSyncSummary(
      processed: processed + 1,
      added: added + (result == _SmsQueueResult.added ? 1 : 0),
      skipped: skipped + (result == _SmsQueueResult.skipped ? 1 : 0),
      failed: failed + (result == _SmsQueueResult.failed ? 1 : 0),
    );
  }
}
