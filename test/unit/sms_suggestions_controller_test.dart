import 'package:ai_expense_tracker/features/expenses/expense_api.dart';
import 'package:ai_expense_tracker/features/sms_suggestions/sms_candidate_factory.dart';
import 'package:ai_expense_tracker/features/sms_suggestions/sms_candidate_repository.dart';
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

    test('parseAndQueue handles a realistic UPI food SMS from Gemma', () async {
      // Arrange
      final database = FakeAppDatabase();
      final createdAt = DateTime(2026, 6, 9, 9, 35);
      final receivedAt = DateTime(2026, 6, 9, 9, 30);
      const body =
          'ICICI Bank: INR 487.50 debited from A/c XX9087 via UPI to ZOMATO LTD on 09-Jun-26. UPI Ref 618245903112. Avl Bal INR 24,812.30.';
      final parsedExpense = ParsedExpense(
        amount: 487.50,
        currency: 'INR',
        date: receivedAt,
        payee: 'ZOMATO LTD',
        category: ExpenseCategory.food,
        transactionKind: TransactionKind.expense,
        paymentMethod: PaymentMethodKind.upi,
        confidence: 0.91,
        reason: 'Gemma parsed merchant UPI food spend.',
        isPersonLike: false,
        accountHint: 'A/c XX9087',
        sourceLabel: 'ICICI UPI',
        fundingSourceLabel: 'ICICI Account •9087',
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          gemmaGatewayProvider.overrideWithValue(
            _FakeGemmaGateway(parsedExpense),
          ),
          smsGatewayProvider.overrideWithValue(const _FakeSmsGateway()),
          parsedExpenseConfirmerProvider.overrideWithValue(
            const _NoopParsedExpenseConfirmer(),
          ),
          expenseReloaderProvider.overrideWithValue(const _NoopReloader()),
          nowProvider.overrideWithValue(() => createdAt),
          idGeneratorProvider.overrideWithValue(() => 'realistic-sms-1'),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final controller = container.read(
        smsSuggestionsControllerProvider.notifier,
      );
      await controller.parseAndQueue(
        sender: 'ICICIB',
        body: body,
        receivedAt: receivedAt,
      );

      // Assert
      final candidates = await container.read(
        smsSuggestionsControllerProvider.future,
      );
      expect(candidates, hasLength(1));
      final candidate = candidates.single;
      expect(candidate.id, 'realistic-sms-1');
      expect(candidate.sender, 'ICICIB');
      expect(candidate.receivedAt, receivedAt);
      expect(candidate.createdAt, createdAt);
      expect(candidate.status, SmsCandidateStatus.pending);
      expect(candidate.bodyHash, smsBodyHash(body));
      expect(candidate.redactedPreview, isNot(contains('XX9087')));
      expect(candidate.redactedPreview, contains('A/c ***'));

      final parsed = candidate.proposedExpense;
      expect(parsed.amount, 487.50);
      expect(parsed.currency, 'INR');
      expect(parsed.date, receivedAt);
      expect(parsed.payee, 'ZOMATO LTD');
      expect(parsed.category, ExpenseCategory.food);
      expect(parsed.transactionKind, TransactionKind.expense);
      expect(parsed.paymentMethod, PaymentMethodKind.upi);
      expect(parsed.sourceLabel, contains('ICICI'));
      expect(parsed.fundingSourceLabel, contains('Account'));
      expect(parsed.accountHint, contains('9087'));
      expect(parsed.confidence, greaterThanOrEqualTo(0.9));
      expect(candidate.modelReason, 'Gemma parsed merchant UPI food spend.');
    });

    test(
      'parseAndQueue fails instead of queueing when Gemma is unavailable',
      () async {
        // Arrange
        final database = FakeAppDatabase();
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            gemmaGatewayProvider.overrideWithValue(const _NullGemmaGateway()),
            smsGatewayProvider.overrideWithValue(const _FakeSmsGateway()),
            parsedExpenseConfirmerProvider.overrideWithValue(
              const _NoopParsedExpenseConfirmer(),
            ),
            expenseReloaderProvider.overrideWithValue(const _NoopReloader()),
            nowProvider.overrideWithValue(() => DateTime(2026, 6, 9, 9, 35)),
            idGeneratorProvider.overrideWithValue(() => 'unavailable-gemma'),
          ],
        );
        addTearDown(container.dispose);
        final progressUpdates = <SmsSyncProgress?>[];
        container.listen<SmsSyncProgress?>(
          smsSyncProgressProvider,
          (_, next) => progressUpdates.add(next),
        );

        // Act
        final controller = container.read(
          smsSuggestionsControllerProvider.notifier,
        );
        await expectLater(
          controller.parseAndQueue(
            sender: 'ICICIB',
            body:
                'ICICI Bank: INR 487.50 debited from A/c XX9087 via UPI to ZOMATO LTD.',
            receivedAt: DateTime(2026, 6, 9, 9, 30),
          ),
          throwsStateError,
        );

        // Assert
        final candidates = await container.read(
          smsSuggestionsControllerProvider.future,
        );
        expect(candidates, isEmpty);
      },
    );

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

    test(
      'syncInbox queues inbox messages and exposes refreshed state',
      () async {
        // Arrange
        final database = FakeAppDatabase();
        final receivedAt = DateTime(2026, 6, 1, 10);
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            gemmaGatewayProvider.overrideWithValue(
              _FakeGemmaGateway(_parsedExpense(receivedAt)),
            ),
            smsGatewayProvider.overrideWithValue(
              _FakeSmsGateway(
                inboxMessages: [
                  NativeSmsMessage(
                    sender: 'HDFCBK',
                    body: 'HDFC Bank: Rs. 642.00 debited from A/c XX2182.',
                    receivedAt: receivedAt,
                  ),
                ],
              ),
            ),
            parsedExpenseConfirmerProvider.overrideWithValue(
              const _NoopParsedExpenseConfirmer(),
            ),
            expenseReloaderProvider.overrideWithValue(const _NoopReloader()),
            nowProvider.overrideWithValue(() => DateTime(2026, 6, 1, 12)),
            idGeneratorProvider.overrideWithValue(() => 'synced-candidate'),
          ],
        );
        addTearDown(container.dispose);
        final progressUpdates = <SmsSyncProgress?>[];
        container.listen<SmsSyncProgress?>(
          smsSyncProgressProvider,
          (_, next) => progressUpdates.add(next),
        );

        // Act
        final controller = container.read(
          smsSuggestionsControllerProvider.notifier,
        );
        await controller.syncInbox(DateTime(2026, 6, 1), DateTime(2026, 6, 2));

        // Assert
        final candidates = container
            .read(smsSuggestionsControllerProvider)
            .value;
        expect(candidates, hasLength(1));
        expect(candidates?.single.id, 'synced-candidate');
        expect(
          progressUpdates.whereType<SmsSyncProgress>().map(
            (progress) =>
                '${progress.processed}/${progress.total}/${progress.added}/${progress.skipped}/${progress.failed}',
          ),
          containsAllInOrder(['0/0/0/0/0', '0/1/0/0/0', '1/1/1/0/0']),
        );
        expect(progressUpdates.last, isNull);
      },
    );

    test('syncInbox skips individual Gemma parse failures', () async {
      // Arrange
      final database = FakeAppDatabase();
      final validReceivedAt = DateTime(2026, 6, 1, 10);
      var id = 0;
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          gemmaGatewayProvider.overrideWithValue(
            _BodyAwareGemmaGateway(
              parse: (body) {
                if (body.contains('SWIGGY')) {
                  return _parsedExpense(validReceivedAt);
                }
                throw StateError('Gemma returned invalid JSON.');
              },
            ),
          ),
          smsGatewayProvider.overrideWithValue(
            _FakeSmsGateway(
              inboxMessages: [
                NativeSmsMessage(
                  sender: 'HDFCBK',
                  body:
                      'HDFC Bank: Rs. 642.00 debited from A/c XX2182 via UPI to SWIGGY.',
                  receivedAt: validReceivedAt,
                ),
                NativeSmsMessage(
                  sender: 'BANK',
                  body: 'Your monthly bank statement is ready.',
                  receivedAt: DateTime(2026, 6, 1, 11),
                ),
              ],
            ),
          ),
          parsedExpenseConfirmerProvider.overrideWithValue(
            const _NoopParsedExpenseConfirmer(),
          ),
          expenseReloaderProvider.overrideWithValue(const _NoopReloader()),
          nowProvider.overrideWithValue(() => DateTime(2026, 6, 1, 12)),
          idGeneratorProvider.overrideWithValue(() => 'synced-${++id}'),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final controller = container.read(
        smsSuggestionsControllerProvider.notifier,
      );
      await controller.syncInbox(DateTime(2026, 6, 1), DateTime(2026, 6, 2));

      // Assert
      final candidates = container.read(smsSuggestionsControllerProvider).value;
      expect(candidates, hasLength(1));
      expect(candidates?.single.id, 'synced-1');
      expect(candidates?.single.proposedExpense.payee, 'Swiggy');
    });

    test('syncInbox exposes query errors through AsyncValue', () async {
      // Arrange
      final database = FakeAppDatabase();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          gemmaGatewayProvider.overrideWithValue(
            _FakeGemmaGateway(_parsedExpense(DateTime(2026, 6, 1))),
          ),
          smsGatewayProvider.overrideWithValue(
            _FakeSmsGateway(error: Exception('SMS unavailable')),
          ),
          parsedExpenseConfirmerProvider.overrideWithValue(
            const _NoopParsedExpenseConfirmer(),
          ),
          expenseReloaderProvider.overrideWithValue(const _NoopReloader()),
          nowProvider.overrideWithValue(() => DateTime(2026, 6, 1, 12)),
          idGeneratorProvider.overrideWithValue(() => 'candidate'),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final controller = container.read(
        smsSuggestionsControllerProvider.notifier,
      );
      await controller.syncInbox(DateTime(2026, 6, 1), DateTime(2026, 6, 2));

      // Assert
      final state = container.read(smsSuggestionsControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<Exception>());
    });

    test('injectDemoSms injects body and drains native queue', () async {
      final database = FakeAppDatabase();
      final spySms = _SpySmsGateway();
      final parsed = _parsedExpense(DateTime(2026, 6, 1));
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          gemmaGatewayProvider.overrideWithValue(_FakeGemmaGateway(parsed)),
          smsGatewayProvider.overrideWithValue(spySms),
          parsedExpenseConfirmerProvider.overrideWithValue(const _NoopParsedExpenseConfirmer()),
          expenseReloaderProvider.overrideWithValue(const _NoopReloader()),
          nowProvider.overrideWithValue(() => DateTime(2026, 6, 1)),
          idGeneratorProvider.overrideWithValue(() => 'demoid'),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(smsSuggestionsControllerProvider.notifier);
      await controller.injectDemoSms();

      expect(spySms.injectedBodies, hasLength(1));
      expect(spySms.injectedBodies.first, contains('SWIGGY'));
      expect(spySms.drainCalled, isTrue);

      final candidates = await container.read(smsSuggestionsControllerProvider.future);
      expect(candidates, hasLength(1));
      expect(candidates.first.id, 'demoid');
    });

    test('confirm calls confirmer and updates candidate status to confirmed', () async {
      final database = FakeAppDatabase();
      final candidate = SmsCandidate(
        id: 'c1',
        sender: 'SBI',
        receivedAt: DateTime(2026, 6, 1),
        bodyHash: 'hash1',
        redactedPreview: 'Debited 500',
        status: SmsCandidateStatus.pending,
        modelReason: 'Standard',
        createdAt: DateTime(2026, 6, 1),
        proposedExpense: _parsedExpense(DateTime(2026, 6, 1)),
      );
      await database.smsCandidates.put('c1', candidate.toJson());

      final spyConfirmer = _SpyParsedExpenseConfirmer();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          parsedExpenseConfirmerProvider.overrideWithValue(spyConfirmer),
          expenseReloaderProvider.overrideWithValue(const _NoopReloader()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(smsSuggestionsControllerProvider.notifier);
      await controller.confirm(candidate);

      expect(spyConfirmer.confirmedParsed, isNotNull);
      expect(spyConfirmer.confirmedParsed!.amount, candidate.proposedExpense.amount);
      expect(spyConfirmer.confirmedSmsHash, candidate.bodyHash);

      final candidates = await container.read(smsSuggestionsControllerProvider.future);
      expect(candidates, isEmpty); // confirmed candidates are not pending anymore

      final repo = container.read(smsCandidateRepositoryProvider);
      final updated = await repo.byId('c1');
      expect(updated!.status, SmsCandidateStatus.confirmed);
    });

    test('edit updates parsed expense and retains candidate status as pending', () async {
      final database = FakeAppDatabase();
      final candidate = SmsCandidate(
        id: 'c1',
        sender: 'SBI',
        receivedAt: DateTime(2026, 6, 1),
        bodyHash: 'hash1',
        redactedPreview: 'Debited 500',
        status: SmsCandidateStatus.pending,
        modelReason: 'Standard',
        createdAt: DateTime(2026, 6, 1),
        proposedExpense: _parsedExpense(DateTime(2026, 6, 1)),
      );
      await database.smsCandidates.put('c1', candidate.toJson());

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(smsSuggestionsControllerProvider.notifier);
      final editedParsed = candidate.proposedExpense.copyWith(amount: 400);

      await controller.edit(candidate, editedParsed);

      final repo = container.read(smsCandidateRepositoryProvider);
      final updated = await repo.byId('c1');
      expect(updated!.status, SmsCandidateStatus.pending);
      expect(updated.proposedExpense.amount, 400);
      expect(updated.modelReason, 'Edited by user after on-device parsing.');
    });

    test('ignore updates candidate status to ignored', () async {
      final database = FakeAppDatabase();
      final candidate = SmsCandidate(
        id: 'c1',
        sender: 'SBI',
        receivedAt: DateTime(2026, 6, 1),
        bodyHash: 'hash1',
        redactedPreview: 'Debited 500',
        status: SmsCandidateStatus.pending,
        modelReason: 'Standard',
        createdAt: DateTime(2026, 6, 1),
        proposedExpense: _parsedExpense(DateTime(2026, 6, 1)),
      );
      await database.smsCandidates.put('c1', candidate.toJson());

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(smsSuggestionsControllerProvider.notifier);
      await controller.ignore(candidate);

      final repo = container.read(smsCandidateRepositoryProvider);
      final updated = await repo.byId('c1');
      expect(updated!.status, SmsCandidateStatus.ignored);
    });
  });
}

final class _SpySmsGateway implements SmsGateway {
  final List<String> injectedBodies = [];
  bool drainCalled = false;

  @override
  Future<List<NativeSmsMessage>> drainPending() async {
    drainCalled = true;
    return [
      NativeSmsMessage(
        sender: 'HDFCBK',
        body: 'HDFC Bank: Rs. 642.00 debited from A/c XX2182 via UPI to SWIGGY on 01-Jun.',
        receivedAt: DateTime(2026, 6, 1, 12),
      ),
    ];
  }

  @override
  Future<void> injectFakeSms(String body) async {
    injectedBodies.add(body);
  }

  @override
  Future<List<NativeSmsMessage>> queryInbox(DateTime start, DateTime end) async => [];

  @override
  Future<void> showSyncNotification({
    required String title,
    required String message,
    required int progress,
    required int max,
  }) async {}

  @override
  Future<void> cancelSyncNotification() async {}
}

final class _SpyParsedExpenseConfirmer implements ParsedExpenseConfirmer {
  ParsedExpense? confirmedParsed;
  String? confirmedSmsHash;

  @override
  Future<Expense> confirmParsed({
    required ParsedExpense parsed,
    required String smsHash,
    String? notes,
  }) async {
    confirmedParsed = parsed;
    confirmedSmsHash = smsHash;
    return Expense(
      id: 'exp-1',
      amount: parsed.amount,
      currency: parsed.currency,
      occurredAt: parsed.date,
      payee: parsed.payee,
      category: parsed.category,
      source: ExpenseSource.sms,
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );
  }
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

final class _BodyAwareGemmaGateway implements GemmaGateway {
  const _BodyAwareGemmaGateway({required this.parse});

  final ParsedExpense Function(String body) parse;

  @override
  Future<GemmaRuntimeDiagnostics> diagnostics() async {
    return const GemmaRuntimeDiagnostics(loaded: false);
  }

  @override
  Future<bool> loadModel(String path) async => true;

  @override
  Future<ParsedExpense?> parseSms(String smsBody) async => parse(smsBody);
}

final class _NullGemmaGateway implements GemmaGateway {
  const _NullGemmaGateway();

  @override
  Future<GemmaRuntimeDiagnostics> diagnostics() async {
    return const GemmaRuntimeDiagnostics(loaded: false);
  }

  @override
  Future<bool> loadModel(String path) async => false;

  @override
  Future<ParsedExpense?> parseSms(String smsBody) async => null;
}

final class _FakeSmsGateway implements SmsGateway {
  const _FakeSmsGateway({
    this.inboxMessages = const [],
    this.error,
  });

  final List<NativeSmsMessage> inboxMessages;
  final Exception? error;

  @override
  Future<List<NativeSmsMessage>> drainPending() async => const [];

  @override
  Future<void> injectFakeSms(String body) async {}

  @override
  Future<List<NativeSmsMessage>> queryInbox(
    DateTime start,
    DateTime end,
  ) async {
    final error = this.error;
    if (error != null) throw error;
    return inboxMessages;
  }

  @override
  Future<void> showSyncNotification({
    required String title,
    required String message,
    required int progress,
    required int max,
  }) async {}

  @override
  Future<void> cancelSyncNotification() async {}
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
