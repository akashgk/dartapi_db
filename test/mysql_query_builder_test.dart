/// Unit tests for the MySQL update() parameter-building logic.
///
/// Regression test for Bug 1: when the same column name appears in both
/// the SET clause and the WHERE clause, the parameter map would collide
/// without the `w_` prefix on WHERE params.
///
/// These tests replicate the exact logic from MySqlDatabase.update() and
/// _MySqlTxDB.update() without requiring a running MySQL server.
library;

import 'package:test/test.dart';

// Mirror the parameter-building logic from MySqlDatabase.update().
Map<String, dynamic> _buildUpdateParams(
  Map<String, dynamic> data,
  Map<String, dynamic> where,
) {
  return {...data, ...{for (final k in where.keys) 'w_$k': where[k]}};
}

String _buildUpdateSql(
  String table,
  Map<String, dynamic> data,
  Map<String, dynamic> where,
) {
  final sets = data.keys.map((k) => '$k = :$k').join(', ');
  final conditions = where.keys.map((k) => '$k = :w_$k').join(' AND ');
  return 'UPDATE $table SET $sets WHERE $conditions;';
}

void main() {
  group('MySQL update() parameter builder', () {
    test('SET and WHERE params have distinct keys for distinct columns', () {
      final params = _buildUpdateParams({'name': 'Alice'}, {'email': 'a@a.com'});
      expect(params, containsPair('name', 'Alice'));
      expect(params, containsPair('w_email', 'a@a.com'));
      expect(params.length, equals(2));
    });

    test(
        'overlapping column names do not collide — '
        'WHERE param is prefixed with w_', () {
      // Bug 1 regression: SET name = :name  WHERE name = :w_name
      final params = _buildUpdateParams({'name': 'Alice'}, {'name': 'Bob'});
      expect(params, containsPair('name', 'Alice'));
      expect(params, containsPair('w_name', 'Bob'));
      expect(params.length, equals(2),
          reason: 'Collision would produce length 1 and overwrite a value');
    });

    test('generated SQL uses :name for SET and :w_name for WHERE', () {
      final sql = _buildUpdateSql('users', {'name': 'Alice'}, {'name': 'Bob'});
      expect(sql, contains('name = :name'));
      expect(sql, contains('name = :w_name'));
      expect(sql, isNot(contains('name = :name WHERE name = :name')));
    });

    test('multiple overlapping columns are all prefixed', () {
      final params = _buildUpdateParams(
        {'name': 'New', 'email': 'new@a.com'},
        {'name': 'Old', 'email': 'old@a.com'},
      );
      expect(params, containsPair('name', 'New'));
      expect(params, containsPair('email', 'new@a.com'));
      expect(params, containsPair('w_name', 'Old'));
      expect(params, containsPair('w_email', 'old@a.com'));
      expect(params.length, equals(4));
    });

    test('SQL with multiple columns is built correctly', () {
      final sql = _buildUpdateSql(
        'products',
        {'title': 'Gadget', 'price': 9.99},
        {'id': 42},
      );
      expect(sql, equals('UPDATE products SET title = :title, price = :price WHERE id = :w_id;'));
    });

    test('WHERE params preserve original values regardless of SET values', () {
      // Ensure the WHERE value is not overwritten by the SET value.
      final params = _buildUpdateParams(
        {'status': 'active'},
        {'status': 'pending'},
      );
      expect(params['status'], equals('active'));
      expect(params['w_status'], equals('pending'));
    });
  });
}
