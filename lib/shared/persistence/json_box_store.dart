import 'package:hive_ce_flutter/hive_flutter.dart';

/// Typed JSON entity access over a Hive box.
final class JsonBoxStore<T> {
  /// Creates a typed store.
  const JsonBoxStore({
    required Box<dynamic> box,
    required T Function(Map<dynamic, dynamic> json) fromJson,
    required Map<String, dynamic> Function(T entity) toJson,
    required String Function(T entity) idOf,
  }) : this._(
         box,
         fromJson,
         toJson,
         idOf,
       );

  const JsonBoxStore._(
    this._box,
    this._fromJson,
    this._toJson,
    this._idOf,
  );

  final Box<dynamic> _box;
  final T Function(Map<dynamic, dynamic> json) _fromJson;
  final Map<String, dynamic> Function(T entity) _toJson;
  final String Function(T entity) _idOf;

  /// Returns all valid JSON entities in the box.
  List<T> all() {
    return _box.values
        .whereType<Map<dynamic, dynamic>>()
        .map(_fromJson)
        .toList();
  }

  /// Finds an entity by id.
  T? byId(String id) {
    final value = _box.get(id);
    if (value is! Map<dynamic, dynamic>) return null;
    return _fromJson(value);
  }

  /// Adds or replaces an entity.
  Future<void> upsert(T entity) async {
    await _box.put(_idOf(entity), _toJson(entity));
  }

  /// Deletes an entity by id.
  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
