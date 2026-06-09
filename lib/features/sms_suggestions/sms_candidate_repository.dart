import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/persistence/app_database.dart';
import 'package:ai_expense_tracker/shared/persistence/json_box_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides SMS candidate persistence.
final smsCandidateRepositoryProvider = Provider<SmsCandidateRepository>((ref) {
  return SmsCandidateRepository(ref.watch(appDatabaseProvider));
});

/// Repository that stores SMS candidates awaiting user review.
final class SmsCandidateRepository {
  /// Creates a repository.
  SmsCandidateRepository(AppDatabase database)
    : _store = JsonBoxStore<SmsCandidate>(
        box: database.smsCandidates,
        fromJson: SmsCandidate.fromJson,
        toJson: (candidate) => candidate.toJson(),
        idOf: (candidate) => candidate.id,
      );

  final JsonBoxStore<SmsCandidate> _store;

  /// Returns all suggestions ordered newest first.
  Future<List<SmsCandidate>> all() async =>
      _store.all()..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

  /// Returns pending suggestions.
  Future<List<SmsCandidate>> pending() async {
    final candidates = await all();
    return candidates
        .where((candidate) => candidate.status == SmsCandidateStatus.pending)
        .toList();
  }

  /// Finds a suggestion by id.
  Future<SmsCandidate?> byId(String id) async => _store.byId(id);

  /// Returns whether the SMS hash already exists.
  Future<bool> containsHash(String bodyHash) async {
    final candidates = await all();
    return candidates.any((candidate) => candidate.bodyHash == bodyHash);
  }

  /// Adds or replaces a candidate.
  Future<void> upsert(SmsCandidate candidate) => _store.upsert(candidate);
}
