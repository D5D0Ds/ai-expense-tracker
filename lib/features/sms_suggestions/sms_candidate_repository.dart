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

  /// Returns all suggestions ordered by time of happening, newest first.
  Future<List<SmsCandidate>> all() async =>
      _store.all()
        ..sort((a, b) => b.proposedExpense.date.compareTo(a.proposedExpense.date));

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

  /// Returns whether a pending (unreviewed) candidate with this hash exists.
  /// Ignored or confirmed candidates are not counted so they can re-appear.
  ///
  /// Scans the box directly without sorting to avoid O(n log n) overhead
  /// during inbox sync where this is called for every SMS.
  Future<bool> containsPendingHash(String bodyHash) async {
    for (final entry in _store.rawValues) {
      if (entry is! Map<dynamic, dynamic>) continue;
      if (entry['bodyHash'] == bodyHash &&
          entry['status'] == SmsCandidateStatus.pending.name) {
        return true;
      }
    }
    return false;
  }

  /// Adds or replaces a candidate.
  Future<void> upsert(SmsCandidate candidate) => _store.upsert(candidate);
}
