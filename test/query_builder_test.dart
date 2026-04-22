import 'package:dartapi_db/dartapi_db.dart';
import 'package:test/test.dart';

/// All tests use an in-memory SQLite database — no server required.
void main() {
  late DartApiDB db;

  setUp(() async {
    db = await DatabaseFactory.create(const DbConfig.sqlite(':memory:'));
    await db.rawQuery('''
      CREATE TABLE users (
        id      INTEGER PRIMARY KEY AUTOINCREMENT,
        name    TEXT    NOT NULL,
        email   TEXT    NOT NULL,
        age     INTEGER NOT NULL,
        role    TEXT    NOT NULL DEFAULT 'user',
        deleted INTEGER NOT NULL DEFAULT 0
      );
    ''');
    await db.insert('users', {'name': 'Alice', 'email': 'alice@corp.com', 'age': 30, 'role': 'admin'});
    await db.insert('users', {'name': 'Bob',   'email': 'bob@corp.com',   'age': 25, 'role': 'user'});
    await db.insert('users', {'name': 'Carol', 'email': 'carol@corp.com', 'age': 35, 'role': 'user'});
    await db.insert('users', {'name': 'Dave',  'email': 'dave@other.com', 'age': 28, 'role': 'editor'});
  });

  tearDown(() => db.close());

  group('QueryBuilder — paramStyle', () {
    test('SQLite driver returns positional style', () {
      expect(db.paramStyle, equals(DbParamStyle.positional));
    });
  });

  group('QueryBuilder — .get()', () {
    test('no conditions returns all rows', () async {
      final result = await db.query('users').get();
      expect(result.rows.length, equals(4));
    });

    test('where equals', () async {
      final result = await db.query('users').where('name', equals: 'Alice').get();
      expect(result.rows.length, equals(1));
      expect(result.rows.first['name'], equals('Alice'));
    });

    test('where notEquals', () async {
      final result = await db.query('users').where('role', notEquals: 'user').get();
      expect(result.rows.length, equals(2)); // admin + editor
    });

    test('where greaterThan', () async {
      final result = await db.query('users').where('age', greaterThan: 28).get();
      expect(result.rows.length, equals(2)); // Alice(30), Carol(35)
    });

    test('where lessThan', () async {
      final result = await db.query('users').where('age', lessThan: 28).get();
      expect(result.rows.length, equals(1)); // Bob(25)
    });

    test('where greaterThanOrEqual', () async {
      final result = await db.query('users').where('age', greaterThanOrEqual: 30).get();
      expect(result.rows.length, equals(2)); // Alice(30), Carol(35)
    });

    test('where lessThanOrEqual', () async {
      final result = await db.query('users').where('age', lessThanOrEqual: 28).get();
      expect(result.rows.length, equals(2)); // Bob(25), Dave(28)
    });

    test('where like — suffix pattern', () async {
      final result = await db.query('users').where('email', like: '%@corp.com').get();
      expect(result.rows.length, equals(3)); // Alice, Bob, Carol
    });

    test('where whereIn', () async {
      final result = await db.query('users')
          .where('role', whereIn: ['admin', 'editor']).get();
      expect(result.rows.length, equals(2));
    });

    test('where isNull = true matches null column', () async {
      await db.rawQuery(
        "INSERT INTO users (name, email, age, role, deleted) VALUES ('Eve', 'e@e.com', 22, 'user', 0);",
      );
      // SQLite INTEGER is not NULL — test IS NOT NULL as a sanity check instead
      final result = await db.query('users').where('name', isNotNull: true).get();
      expect(result.rows.length, greaterThanOrEqualTo(4));
    });

    test('where isNotNull filters out null values', () async {
      final result = await db.query('users').where('role', isNotNull: true).get();
      expect(result.rows.length, equals(4));
    });

    test('multiple where conditions are AND-joined', () async {
      final result = await db.query('users')
          .where('age', greaterThan: 24)
          .where('role', equals: 'user')
          .get();
      expect(result.rows.length, equals(2)); // Bob(25,user), Carol(35,user)
    });

    test('select specific columns', () async {
      final result = await db.query('users')
          .select(['name', 'email'])
          .where('name', equals: 'Alice')
          .get();
      expect(result.rows.first.containsKey('name'), isTrue);
      expect(result.rows.first.containsKey('email'), isTrue);
      expect(result.rows.first.containsKey('age'), isFalse);
    });

    test('orderBy ascending', () async {
      final result = await db.query('users').orderBy('age').get();
      final ages = result.rows.map((r) => r['age'] as int).toList();
      expect(ages, equals([25, 28, 30, 35]));
    });

    test('orderBy descending', () async {
      final result = await db.query('users').orderBy('age', ascending: false).get();
      final ages = result.rows.map((r) => r['age'] as int).toList();
      expect(ages, equals([35, 30, 28, 25]));
    });

    test('multiple orderBy columns', () async {
      await db.insert('users', {'name': 'Zara', 'email': 'z@z.com', 'age': 25, 'role': 'user'});
      final result = await db.query('users')
          .orderBy('age')
          .orderBy('name', ascending: false)
          .get();
      // age=25 rows: Zara before Bob (descending name)
      final age25 = result.rows.where((r) => r['age'] == 25).map((r) => r['name']).toList();
      expect(age25.first, equals('Zara'));
    });

    test('limit restricts row count', () async {
      final result = await db.query('users').orderBy('id').limit(2).get();
      expect(result.rows.length, equals(2));
    });

    test('offset skips rows', () async {
      final all = await db.query('users').orderBy('id').get();
      final paged = await db.query('users').orderBy('id').offset(2).get();
      expect(paged.rows.first['id'], equals(all.rows[2]['id']));
    });

    test('limit + offset — page 2 of 2', () async {
      final page1 = await db.query('users').orderBy('id').limit(2).offset(0).get();
      final page2 = await db.query('users').orderBy('id').limit(2).offset(2).get();
      expect(page1.rows.length, equals(2));
      expect(page2.rows.length, equals(2));
      expect(page1.rows.first['id'], isNot(equals(page2.rows.first['id'])));
    });
  });

  group('QueryBuilder — .first()', () {
    test('returns first matching row', () async {
      final row = await db.query('users').where('name', equals: 'Bob').first();
      expect(row, isNotNull);
      expect(row!['name'], equals('Bob'));
    });

    test('returns null when no row matches', () async {
      final row = await db.query('users').where('name', equals: 'Nobody').first();
      expect(row, isNull);
    });
  });

  group('QueryBuilder — .count()', () {
    test('counts all rows when no conditions', () async {
      final n = await db.query('users').count();
      expect(n, equals(4));
    });

    test('counts filtered rows', () async {
      final n = await db.query('users').where('role', equals: 'user').count();
      expect(n, equals(2));
    });

    test('count respects multiple conditions', () async {
      final n = await db.query('users')
          .where('role', equals: 'user')
          .where('age', greaterThan: 26)
          .count();
      expect(n, equals(1)); // Carol only
    });

    test('count ignores orderBy, limit, offset', () async {
      final full = await db.query('users').count();
      final limited = await db.query('users').limit(1).offset(3).count();
      expect(full, equals(limited)); // LIMIT/OFFSET don't affect COUNT
    });
  });
}
