import 'package:ai_expense_tracker/shared/persistence/json_box_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_app_database.dart';

void main() {
  group('JsonBoxStore', () {
    test('loads valid JSON entities and ignores invalid entries', () {
      // Arrange
      final box = FakeBox()
        ..seed('one', {'id': 'one', 'value': 1})
        ..seed('invalid', 'not-json');
      final store = _store(box);

      // Act
      final result = store.all();

      // Assert
      expect(result, const [_FakeEntity('one', 1)]);
    });

    test('finds, upserts, and deletes by id', () async {
      // Arrange
      final box = FakeBox();
      final store = _store(box);

      // Act
      await store.upsert(const _FakeEntity('one', 1));
      final saved = store.byId('one');
      await store.delete('one');

      // Assert
      expect(saved, const _FakeEntity('one', 1));
      expect(store.byId('one'), isNull);
    });
  });
}

JsonBoxStore<_FakeEntity> _store(FakeBox box) {
  return JsonBoxStore<_FakeEntity>(
    box: box,
    fromJson: _FakeEntity.fromJson,
    toJson: (entity) => entity.toJson(),
    idOf: (entity) => entity.id,
  );
}

@immutable
final class _FakeEntity {
  const _FakeEntity(this.id, this.value);

  final String id;
  final int value;

  factory _FakeEntity.fromJson(Map<dynamic, dynamic> json) {
    return _FakeEntity(json['id'] as String, json['value'] as int);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'value': value,
  };

  @override
  bool operator ==(Object other) {
    return other is _FakeEntity && other.id == id && other.value == value;
  }

  @override
  int get hashCode => Object.hash(id, value);

  @override
  String toString() => '_FakeEntity($id, $value)';
}
