import 'package:ai_expense_tracker/features/expenses/expense_api.dart';
import 'package:ai_expense_tracker/features/sms_suggestions/sms_candidate_factory.dart';
import 'package:ai_expense_tracker/features/sms_suggestions/sms_suggestions_controller.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:ai_expense_tracker/shared/persistence/app_database.dart';
import 'package:ai_expense_tracker/shared/platform/gemma_bridge.dart';
import 'package:ai_expense_tracker/shared/platform/native_sms_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_app_database.dart';

void main() {
  group('SmsSuggestionsController', () {
    test('parseAndQueue stores a deterministic pending candidate', () async {
      // Arrange
      final database = FakeAppDatabase();
      final createdAt = DateTime(2026, 6, 1, 12);
      final receivedAt = DateTime(2026, 6, 1, 10);
      final parsed = _parsedExpense(receivedAt);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          gemmaGatewayProvider.overrideWithValue(_FakeGemmaGateway(parsed)),
          smsGatewayProvider.overrideWithValue(const _FakeSmsGateway()),
          parsedExpenseConfirmerProvider.overrideWithValue(
            const _NoopParsedExpenseConfirmer(),
          ),
          expenseReloaderProvider.overrideWithValue(const _NoopReloader()),
          nowProvider.overrideWithValue(() => createdAt),
          idGeneratorProvider.overrideWithValue(() => 'candidate-1'),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final controller = container.read(
        smsSuggestionsControllerProvider.notifier,
      );
      await controller.parseAndQueue(
        sender: 'HDFCBK',
        body: 'HDFC Bank: Rs. 642.00 debited from A/c XX2182.',
        receivedAt: receivedAt,
      );

      // Assert
      final candidates = await container.read(
        smsSuggestionsControllerProvider.future,
      );
      expect(candidates, hasLength(1));
      final candidate = candidates.single;
      expect(candidate.id, 'candidate-1');
      expect(candidate.sender, 'HDFCBK');
      expect(candidate.receivedAt, receivedAt);
      expect(candidate.createdAt, createdAt);
      expect(candidate.status, SmsCandidateStatus.pending);
      expect(
        candidate.bodyHash,
        smsBodyHash('HDFC Bank: Rs. 642.00 debited from A/c XX2182.'),
      );
      expect(candidate.redactedPreview, isNot(contains('XX2182')));
      expect(candidate.proposedExpense.amount, parsed.amount);
      expect(candidate.proposedExpense.payee, parsed.payee);
      expect(candidate.proposedExpense.category, parsed.category);
    });

    test('parseAndQueue ignores duplicate SMS body hashes', () async {
      // Arrange
      final smsCandidates = FakeBox();
      final database = FakeAppDatabase(smsCandidates: smsCandidates);
      const body = 'HDFC Bank: Rs. 642.00 debited from A/c XX2182.';
      smsCandidates.seed('existing', {
        'id': 'existing',
        'sender': 'HDFCBK',
        'receivedAt': DateTime(2026, 6, 1, 10).toIso8601String(),
        'bodyHash': smsBodyHash(body),
        'redactedPreview': 'HDFC Bank: Rs. 642.00 debited from A/c ***.',
        'status': SmsCandidateStatus.pending.name,
        'proposedExpense': _parsedExpense(DateTime(2026, 6, 1)).toJson(),
        'modelReason': 'Parsed on device.',
        'createdAt': DateTime(2026, 6, 1, 11).toIso8601String(),
      });
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          gemmaGatewayProvider.overrideWithValue(
            _FakeGemmaGateway(_parsedExpense(DateTime(2026, 6, 1))),
          ),
          smsGatewayProvider.overrideWithValue(const _FakeSmsGateway()),
          parsedExpenseConfirmerProvider.overrideWithValue(
            const _NoopParsedExpenseConfirmer(),
          ),
          expenseReloaderProvider.overrideWithValue(const _NoopReloader()),
          nowProvider.overrideWithValue(() => DateTime(2026, 6, 1, 12)),
          idGeneratorProvider.overrideWithValue(() => 'new-candidate'),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final controller = container.read(
        smsSuggestionsControllerProvider.notifier,
      );
      await controller.parseAndQueue(
        sender: 'HDFCBK',
        body: body,
        receivedAt: DateTime(2026, 6, 1, 10),
      );

      // Assert
      final candidates = await container.read(
        smsSuggestionsControllerProvider.future,
      );
      expect(candidates.map((candidate) => candidate.id), ['existing']);
    });
  });
}

ParsedExpense _parsedExpense(DateTime date) {
  return ParsedExpense(
    amount: 642,
    currency: 'INR',
    date: date,
    payee: 'Swiggy',
    category: ExpenseCategory.food,
    confidence: 0.8,
    reason: 'Parsed on device.',
    isPersonLike: false,
  );
}

final class _FakeGemmaGateway implements GemmaGateway {
  const _FakeGemmaGateway(this.parsed);

  final ParsedExpense parsed;

  @override
  Future<GemmaRuntimeDiagnostics> diagnostics() async {
    return const GemmaRuntimeDiagnostics(loaded: false);
  }

  @override
  Future<bool> loadModel(String path) async => true;

  @override
  Future<ParsedExpense?> parseSms(String smsBody) async => parsed;
}

final class _FakeSmsGateway implements SmsGateway {
  const _FakeSmsGateway();

  @override
  Future<List<NativeSmsMessage>> drainPending() async => const [];

  @override
  Future<void> injectFakeSms(String body) async {}

  @override
  Future<List<NativeSmsMessage>> queryInbox(
    DateTime start,
    DateTime end,
  ) async {
    return const [];
  }
}

final class _NoopParsedExpenseConfirmer implements ParsedExpenseConfirmer {
  const _NoopParsedExpenseConfirmer();

  @override
  Future<Expense> confirmParsed({
    required ParsedExpense parsed,
    required String smsHash,
    String? notes,
  }) async {
    return Expense(
      id: 'expense',
      amount: parsed.amount,
      currency: parsed.currency,
      occurredAt: parsed.date,
      payee: parsed.payee,
      category: parsed.category,
      source: ExpenseSource.sms,
      createdAt: parsed.date,
      updatedAt: parsed.date,
    );
  }
}

final class _NoopReloader implements ExpenseReloader {
  const _NoopReloader();

  @override
  Future<void> reload() async {}
}
