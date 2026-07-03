import 'package:dartapi_db/dartapi_db.dart';
import 'package:test/test.dart';

Future<DartApiDB> _memDb() async {
  final db = await DatabaseFactory.create(DbConfig.sqlite(':memory:'));
  await db.rawQuery(
    'CREATE TABLE users ('
    'id INTEGER PRIMARY KEY AUTOINCREMENT, '
    'email TEXT NOT NULL UNIQUE, '
    'name TEXT NOT NULL);',
  );
  return db;
}

void main() {
  group('typed exceptions (SQLite)', () {
    test('duplicate insert throws UniqueViolationException', () async {
      final db = await _memDb();
      await db.insert('users', {'email': 'a@x.com', 'name': 'A'});
      await expectLater(
        db.insert('users', {'email': 'a@x.com', 'name': 'A2'}),
        throwsA(isA<UniqueViolationException>()),
      );
      await db.close();
    });

    test('foreign key violation throws ForeignKeyViolationException', () async {
      final db = await _memDb();
      await db.rawQuery('PRAGMA foreign_keys = ON;');
      await db.rawQuery(
        'CREATE TABLE posts (id INTEGER PRIMARY KEY, '
        'user_id INTEGER NOT NULL REFERENCES users(id));',
      );
      await expectLater(
        db.insert('posts', {'id': 1, 'user_id': 999}),
        throwsA(isA<ForeignKeyViolationException>()),
      );
      await db.close();
    });

    test('SQL error throws QueryException with the cause preserved', () async {
      final db = await _memDb();
      try {
        await db.rawQuery('SELECT * FROM no_such_table;');
        fail('expected QueryException');
      } on QueryException catch (e) {
        expect(e.cause, isNotNull);
        expect(e.toString(), contains('QueryException'));
      }
      await db.close();
    });

    test('typed exceptions are DbException subtypes', () {
      expect(const UniqueViolationException('x'), isA<DbException>());
      expect(const ForeignKeyViolationException('x'), isA<DbException>());
      expect(const DbConnectionException('x'), isA<DbException>());
      expect(const QueryException('x'), isA<DbException>());
    });
  });

  group('DbConfig.fromUrl', () {
    test('parses a full postgres URL with sslmode', () {
      final c = DbConfig.fromUrl(
        'postgres://user:p%40ss@db.example.com:6543/mydb?sslmode=require',
      );
      expect(c.type, DbType.postgres);
      expect(c.host, 'db.example.com');
      expect(c.port, 6543);
      expect(c.database, 'mydb');
      expect(c.username, 'user');
      expect(c.password, 'p@ss'); // URL-decoded
      expect(c.useSsl, isTrue);
    });

    test('postgresql:// scheme and default port', () {
      final c = DbConfig.fromUrl('postgresql://u:p@localhost/app');
      expect(c.type, DbType.postgres);
      expect(c.port, 5432);
      expect(c.useSsl, isFalse);
    });

    test('mysql:// with default port and ssl=true', () {
      final c = DbConfig.fromUrl('mysql://root:secret@db/app?ssl=true');
      expect(c.type, DbType.mysql);
      expect(c.port, 3306);
      expect(c.useSsl, isTrue);
    });

    test('sslmode=disable stays plaintext', () {
      final c = DbConfig.fromUrl('postgres://u:p@h/db?sslmode=disable');
      expect(c.useSsl, isFalse);
    });

    test('sqlite variants', () {
      expect(DbConfig.fromUrl('sqlite:app.db').database, 'app.db');
      expect(DbConfig.fromUrl('sqlite::memory:').database, ':memory:');
      expect(DbConfig.fromUrl('sqlite:app.db').type, DbType.sqlite);
    });

    test('rejects unknown schemes and incomplete URLs', () {
      expect(() => DbConfig.fromUrl('mongodb://x/y'), throwsFormatException);
      expect(() => DbConfig.fromUrl('postgres://host'), throwsFormatException);
      expect(() => DbConfig.fromUrl('sqlite:'), throwsFormatException);
    });

    test('DatabaseFactory.fromUrl connects (sqlite)', () async {
      final db = await DatabaseFactory.fromUrl('sqlite::memory:');
      expect(await db.ping(), isTrue);
      await db.close();
    });
  });

  group('paginate()', () {
    test('returns one page plus totals in a single call', () async {
      final db = await _memDb();
      await db.insertBatch('users', [
        for (var i = 1; i <= 25; i++) {'email': 'u$i@x.com', 'name': 'User $i'},
      ]);

      final page = await db
          .query('users')
          .orderBy('id')
          .paginate(page: 2, limit: 10);

      expect(page.total, 25);
      expect(page.rows, hasLength(10));
      expect(page.rows.first['name'], 'User 11');
      expect(page.page, 2);
      expect(page.totalPages, 3);
      expect(page.hasNext, isTrue);
      expect(page.hasPrev, isTrue);
      await db.close();
    });

    test('last page is short and hasNext is false', () async {
      final db = await _memDb();
      await db.insertBatch('users', [
        for (var i = 1; i <= 25; i++) {'email': 'u$i@x.com', 'name': 'User $i'},
      ]);
      final page = await db
          .query('users')
          .orderBy('id')
          .paginate(page: 3, limit: 10);
      expect(page.rows, hasLength(5));
      expect(page.hasNext, isFalse);
      await db.close();
    });

    test('respects WHERE conditions', () async {
      final db = await _memDb();
      await db.insertBatch('users', [
        for (var i = 1; i <= 10; i++)
          {'email': 'u$i@x.com', 'name': i.isEven ? 'even' : 'odd'},
      ]);
      final page = await db
          .query('users')
          .where('name', equals: 'even')
          .orderBy('id')
          .paginate(limit: 3);
      expect(page.total, 5);
      expect(page.rows, hasLength(3));
      await db.close();
    });

    test('empty result set', () async {
      final db = await _memDb();
      final page = await db.query('users').paginate();
      expect(page.total, 0);
      expect(page.isEmpty, isTrue);
      expect(page.totalPages, 0);
      expect(page.hasNext, isFalse);
      expect(page.hasPrev, isFalse);
      await db.close();
    });

    test('clamps page and limit to sane minimums', () async {
      final db = await _memDb();
      await db.insert('users', {'email': 'a@x.com', 'name': 'A'});
      final page = await db.query('users').paginate(page: 0, limit: 0);
      expect(page.page, 1);
      expect(page.limit, 1);
      expect(page.rows, hasLength(1));
      await db.close();
    });

    test('map() converts rows', () async {
      final db = await _memDb();
      await db.insert('users', {'email': 'a@x.com', 'name': 'A'});
      final page = await db.query('users').paginate();
      final names = page.map((r) => r['name'] as String);
      expect(names, ['A']);
      await db.close();
    });
  });

  group('exists()', () {
    test('true when a row matches, false otherwise', () async {
      final db = await _memDb();
      await db.insert('users', {'email': 'a@x.com', 'name': 'A'});
      expect(
        await db.query('users').where('email', equals: 'a@x.com').exists(),
        isTrue,
      );
      expect(
        await db.query('users').where('email', equals: 'b@x.com').exists(),
        isFalse,
      );
      await db.close();
    });
  });

  group('query builder inside transactions', () {
    test('tx.query(...) works and sees uncommitted writes', () async {
      final db = await _memDb();
      await db.transaction((tx) async {
        await tx.insert('users', {'email': 'a@x.com', 'name': 'A'});
        final found =
            await tx.query('users').where('email', equals: 'a@x.com').first();
        expect(found, isNotNull);
        expect(await tx.query('users').count(), 1);
      });
      await db.close();
    });

    test(
      'typed exceptions surface inside transactions and roll back',
      () async {
        final db = await _memDb();
        await db.insert('users', {'email': 'a@x.com', 'name': 'A'});
        await expectLater(
          db.transaction((tx) async {
            await tx.insert('users', {'email': 'b@x.com', 'name': 'B'});
            await tx.insert('users', {'email': 'a@x.com', 'name': 'dup'});
          }),
          throwsA(isA<UniqueViolationException>()),
        );
        // The whole transaction rolled back — B was not committed.
        expect(await db.query('users').count(), 1);
        await db.close();
      },
    );
  });

  group('select limit/offset (interface level)', () {
    test('paginates through the plain select API', () async {
      final db = await _memDb();
      await db.insertBatch('users', [
        for (var i = 1; i <= 5; i++) {'email': 'u$i@x.com', 'name': 'U$i'},
      ]);
      final result = await db.select('users', limit: 2, offset: 2);
      expect(result.rows, hasLength(2));
      expect(result.rows.first['name'], 'U3');
      await db.close();
    });
  });
}
