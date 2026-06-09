import 'package:ai_expense_tracker/features/sms_suggestions/sms_candidate_repository.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/persistence/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_app_database.dart';

void main() {
  group('SmsCandidateRepository', () {
    late FakeAppDatabase db;
    late SmsCandidateRepository repository;

    setUp(() {
      db = FakeAppDatabase();
      repository = SmsCandidateRepository(db);
    });

    test('smsCandidateRepositoryProvider returns the repository instances', () {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(smsCandidateRepositoryProvider);
      expect(repo, isNotNull);
      expect(repo, isA<SmsCandidateRepository>());
    });

    test('upsert and byId returns candidate', () async {
      final candidate = SmsCandidate(
        id: 'c1',
        sender: 'SBI',
        receivedAt: DateTime(2026, 6, 9, 9, 0, 0),
        bodyHash: 'hash500',
        redactedPreview: 'Debited 500',
        status: SmsCandidateStatus.pending,
        modelReason: 'Standard parsing',
        createdAt: DateTime(2026, 6, 9, 9, 0, 0),
        proposedExpense: ParsedExpense(
          amount: 500,
          currency: 'INR',
          date: DateTime(2026, 6, 9, 9, 0, 0),
          payee: 'Grocery',
          category: ExpenseCategory.food,
          transactionKind: TransactionKind.expense,
          paymentMethod: PaymentMethodKind.upi,
          confidence: 0.9,
          reason: 'Valid match',
          isPersonLike: false,
        ),
      );

      await repository.upsert(candidate);

      final fetched = await repository.byId('c1');
      expect(fetched, isNotNull);
      expect(fetched!.id, 'c1');
      expect(fetched.sender, 'SBI');
      expect(fetched.redactedPreview, 'Debited 500');
    });

    test('all() returns candidates ordered by receivedAt newest first', () async {
      final candidate1 = SmsCandidate(
        id: 'c1',
        sender: 'SBI',
        receivedAt: DateTime(2026, 6, 9, 9, 0, 0),
        bodyHash: 'hash1',
        redactedPreview: 'Debited 500',
        status: SmsCandidateStatus.pending,
        modelReason: 'Reason 1',
        createdAt: DateTime(2026, 6, 9, 9, 0, 0),
        proposedExpense: ParsedExpense(
          amount: 500,
          currency: 'INR',
          date: DateTime(2026, 6, 9, 9, 0, 0),
          payee: 'Grocery',
          category: ExpenseCategory.food,
          transactionKind: TransactionKind.expense,
          paymentMethod: PaymentMethodKind.upi,
          confidence: 0.9,
          reason: 'Reason 1',
          isPersonLike: false,
        ),
      );

      final candidate2 = SmsCandidate(
        id: 'c2',
        sender: 'HDFC',
        receivedAt: DateTime(2026, 6, 9, 10, 0, 0),
        bodyHash: 'hash2',
        redactedPreview: 'Debited 100',
        status: SmsCandidateStatus.pending,
        modelReason: 'Reason 2',
        createdAt: DateTime(2026, 6, 9, 10, 0, 0),
        proposedExpense: ParsedExpense(
          amount: 100,
          currency: 'INR',
          date: DateTime(2026, 6, 9, 10, 0, 0),
          payee: 'Cafe',
          category: ExpenseCategory.food,
          transactionKind: TransactionKind.expense,
          paymentMethod: PaymentMethodKind.upi,
          confidence: 0.9,
          reason: 'Reason 2',
          isPersonLike: false,
        ),
      );

      await repository.upsert(candidate1);
      await repository.upsert(candidate2);

      final list = await repository.all();
      expect(list.length, 2);
      expect(list.first.id, 'c2'); // newer (10:00)
      expect(list.last.id, 'c1');  // older (09:00)
    });

    test('containsHash checks if bodyHash is present', () async {
      final candidate = SmsCandidate(
        id: 'c1',
        sender: 'SBI',
        receivedAt: DateTime(2026, 6, 9),
        bodyHash: 'unique-hash-123',
        redactedPreview: 'Debited 500',
        status: SmsCandidateStatus.pending,
        modelReason: 'Standard parsing',
        createdAt: DateTime(2026, 6, 9),
        proposedExpense: ParsedExpense(
          amount: 500,
          currency: 'INR',
          date: DateTime(2026, 6, 9),
          payee: 'Grocery',
          category: ExpenseCategory.food,
          transactionKind: TransactionKind.expense,
          paymentMethod: PaymentMethodKind.upi,
          confidence: 0.9,
          reason: 'Reason',
          isPersonLike: false,
        ),
      );

      await repository.upsert(candidate);

      expect(await repository.containsHash('unique-hash-123'), isTrue);
      expect(await repository.containsHash('other-hash'), isFalse);
    });

    test('pending() returns only pending candidates', () async {
      final pendingCandidate = SmsCandidate(
        id: 'pending_candidate',
        sender: 'SBI',
        receivedAt: DateTime(2026, 6, 9, 9, 0, 0),
        bodyHash: 'hash1',
        redactedPreview: 'Debited 500',
        status: SmsCandidateStatus.pending,
        modelReason: 'Standard Gemma parsing',
        createdAt: DateTime(2026, 6, 9, 9, 0, 0),
        proposedExpense: ParsedExpense(
          amount: 500,
          currency: 'INR',
          date: DateTime(2026, 6, 9, 9, 0, 0),
          payee: 'Grocery',
          category: ExpenseCategory.food,
          transactionKind: TransactionKind.expense,
          paymentMethod: PaymentMethodKind.upi,
          confidence: 0.9,
          reason: 'Gemma match',
          isPersonLike: false,
        ),
      );

      final dismissedCandidate = SmsCandidate(
        id: 'dismissed_candidate',
        sender: 'HDFC',
        receivedAt: DateTime(2026, 6, 9, 8, 0, 0),
        bodyHash: 'hash2',
        redactedPreview: 'Debited 100',
        status: SmsCandidateStatus.ignored,
        modelReason: 'Reason 2',
        createdAt: DateTime(2026, 6, 9, 8, 0, 0),
        proposedExpense: ParsedExpense(
          amount: 100,
          currency: 'INR',
          date: DateTime(2026, 6, 9, 8, 0, 0),
          payee: 'Cafe',
          category: ExpenseCategory.food,
          transactionKind: TransactionKind.expense,
          paymentMethod: PaymentMethodKind.upi,
          confidence: 0.9,
          reason: 'Reason 2',
          isPersonLike: false,
        ),
      );

      await repository.upsert(pendingCandidate);
      await repository.upsert(dismissedCandidate);

      final pendingList = await repository.pending();

      expect(pendingList.length, 1);
      expect(pendingList.first.id, 'pending_candidate');
    });
  });
}
