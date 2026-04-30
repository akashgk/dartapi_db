/// Unit tests verifying that [MySqlDatabase] inherits correct SQL-building
/// logic from [SqlDatabase] with colon-style (`:param`) placeholders.
///
/// A lightweight stub overrides [rawQuery] to capture generated SQL and params
/// instead of hitting a real MySQL server.
library;

import 'package:dartapi_db/core/dartapi_db_core.dart';
import 'package:dartapi_db/core/db_result.dart';
import 'package:dartapi_db/core/db_transaction.dart';
import 'package:dartapi_db/drivers/mysql/mysql_database.dart';
import 'package:dartapi_db/types/db_config.dart';
import 'package:dartapi_db/types/db_type.dart';
import 'package:test/test.dart';

// ── Stub ──────────────────────────────────────────────────────────────────────

class _CapturedQuery {
  final String sql;
  final Map<String, dynamic>? values;
  _CapturedQuery(this.sql, this.values);
}

/// Stub that extends [MySqlDatabase] and captures SQL instead of executing it.
class _StubMySqlDatabase extends MySqlDatabase {
  _CapturedQuery? last;

  _StubMySqlDatabase()
    : super(
        const DbConfig(
          type: DbType.mysql,
          host: 'localhost',
          port: 3306,
          database: 'test',
          username: 'root',
          password: '',
        ),
      );

  @override
  Future<void> connect() async {}

  @override
  Future<void> close() async {}

  @override
  Future<DbResult> rawQuery(
    String query, {
    Map<String, dynamic>? values,
  }) async {
    last = _CapturedQuery(query, values);
    return DbResult(rows: [], affectedRows: 0);
  }

  @override
  Future<T> transaction<T>(Future<T> Function(DbTransaction tx) callback) {
    throw UnimplementedError('not needed in unit tests');
  }
}

void main() {
  late _StubMySqlDatabase db;

  setUp(() => db = _StubMySqlDatabase());

  // ── paramStyle ──────────────────────────────────────────────────────────────

  group('paramStyle', () {
    test('is DbParamStyle.colon', () {
      expect(db.paramStyle, DbParamStyle.colon);
    });
  });

  // ── insert ──────────────────────────────────────────────────────────────────

  group('insert', () {
    test('uses :param placeholders', () async {
      await db.insert('users', {'name': 'Alice', 'email': 'a@example.com'});
      expect(db.last!.sql, contains(':name'));
      expect(db.last!.sql, contains(':email'));
      expect(db.last!.sql, isNot(contains('@name')));
    });

    test('passes data map as values', () async {
      await db.insert('users', {'name': 'Bob'});
      expect(db.last!.values, containsPair('name', 'Bob'));
    });

    test('SQL is a valid INSERT INTO statement', () async {
      await db.insert('products', {'title': 'Gadget', 'price': 9.99});
      expect(
        db.last!.sql,
        equals('INSERT INTO products (title, price) VALUES (:title, :price);'),
      );
    });
  });

  // ── select ──────────────────────────────────────────────────────────────────

  group('select', () {
    test('SELECT * with no where clause', () async {
      await db.select('users');
      expect(db.last!.sql, equals('SELECT * FROM users'));
      expect(db.last!.values, isNull);
    });

    test('WHERE clause uses :param placeholders', () async {
      await db.select('users', where: {'id': 1});
      expect(db.last!.sql, contains('id = :id'));
      expect(db.last!.sql, isNot(contains('@id')));
      expect(db.last!.values, containsPair('id', 1));
    });

    test('multiple WHERE conditions are AND-joined', () async {
      await db.select('users', where: {'role': 'admin', 'active': true});
      expect(db.last!.sql, contains('WHERE'));
      expect(db.last!.sql, contains('AND'));
    });

    test('LIMIT and OFFSET are appended', () async {
      await db.select('users', limit: 10, offset: 20);
      expect(db.last!.sql, contains('LIMIT 10'));
      expect(db.last!.sql, contains('OFFSET 20'));
    });
  });

  // ── update ──────────────────────────────────────────────────────────────────

  group('update', () {
    test('SET uses :param, WHERE uses :w_param', () async {
      await db.update('users', {'name': 'Alice'}, where: {'id': 1});
      expect(db.last!.sql, contains('name = :name'));
      expect(db.last!.sql, contains('id = :w_id'));
    });

    test('overlapping column names do not collide', () async {
      await db.update(
        'users',
        {'status': 'active'},
        where: {'status': 'pending'},
      );
      final values = db.last!.values!;
      expect(values['status'], 'active');
      expect(values['w_status'], 'pending');
      expect(values.length, 2);
    });

    test('generates correct full SQL', () async {
      await db.update(
        'products',
        {'title': 'New', 'price': 5.0},
        where: {'id': 42},
      );
      expect(
        db.last!.sql,
        equals(
          'UPDATE products SET title = :title, price = :price WHERE id = :w_id;',
        ),
      );
    });

    test('no @param placeholders appear', () async {
      await db.update('t', {'a': 1}, where: {'b': 2});
      expect(db.last!.sql, isNot(contains('@')));
    });
  });

  // ── delete ──────────────────────────────────────────────────────────────────

  group('delete', () {
    test('WHERE uses :param placeholders', () async {
      await db.delete('users', where: {'id': 99});
      expect(db.last!.sql, contains('id = :id'));
      expect(db.last!.sql, isNot(contains('@id')));
    });

    test('generates correct full SQL', () async {
      await db.delete('sessions', where: {'token': 'abc'});
      expect(
        db.last!.sql,
        equals('DELETE FROM sessions WHERE token = :token;'),
      );
    });

    test('passes where map as values', () async {
      await db.delete('users', where: {'id': 7});
      expect(db.last!.values, containsPair('id', 7));
    });
  });

  // ── extends SqlDatabase ────────────────────────────────────────────────────

  group('class hierarchy', () {
    test('MySqlDatabase is a SqlDatabase', () {
      expect(db, isA<MySqlDatabase>());
    });

    test('MySqlDatabase satisfies DartApiDB', () {
      expect(db, isA<DartApiDB>());
    });
  });
}
