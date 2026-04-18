import 'dart:io';

import 'package:dartapi_db/dartapi_db.dart';
import 'package:test/test.dart';

/// All tests use an in-memory SQLite database — no server required.
void main() {
  late DartApiDB db;

  setUp(() async {
    db = await DatabaseFactory.create(const DbConfig.sqlite(':memory:'));
    await db.rawQuery('''
      CREATE TABLE users (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        name  TEXT NOT NULL,
        email TEXT NOT NULL
      );
    ''');
  });

  tearDown(() => db.close());

  group('SqliteDatabase - DbConfig.sqlite', () {
    test('DbType is sqlite', () {
      expect(const DbConfig.sqlite('app.db').type, equals(DbType.sqlite));
    });

    test('database field holds the path', () {
      expect(
        const DbConfig.sqlite('data/app.db').database,
        equals('data/app.db'),
      );
    });
  });

  group('SqliteDatabase - CRUD', () {
    test('insert returns affected rows and insertId', () async {
      final result = await db.insert('users', {
        'name': 'Alice',
        'email': 'alice@example.com',
      });
      expect(result.affectedRows, equals(1));
      expect(result.insertId, isNotNull);
    });

    test('select returns all rows', () async {
      await db.insert('users', {'name': 'Alice', 'email': 'a@a.com'});
      await db.insert('users', {'name': 'Bob', 'email': 'b@b.com'});
      final result = await db.select('users');
      expect(result.rows.length, equals(2));
    });

    test('select with where filters rows', () async {
      await db.insert('users', {'name': 'Alice', 'email': 'a@a.com'});
      await db.insert('users', {'name': 'Bob', 'email': 'b@b.com'});
      final result = await db.select('users', where: {'name': 'Alice'});
      expect(result.rows.length, equals(1));
      expect(result.rows.first['name'], equals('Alice'));
    });

    test('update modifies matching rows', () async {
      await db.insert('users', {'name': 'Alice', 'email': 'a@a.com'});
      await db.update(
        'users',
        {'name': 'Alicia'},
        where: {'email': 'a@a.com'},
      );
      final result = await db.select('users', where: {'email': 'a@a.com'});
      expect(result.rows.first['name'], equals('Alicia'));
    });

    test('delete removes matching rows', () async {
      await db.insert('users', {'name': 'Alice', 'email': 'a@a.com'});
      await db.delete('users', where: {'email': 'a@a.com'});
      final result = await db.select('users');
      expect(result.isEmpty, isTrue);
    });

    test('rawQuery executes DDL', () async {
      await db.rawQuery(
        'CREATE TABLE items (id INTEGER PRIMARY KEY, label TEXT);',
      );
      await db.rawQuery(
        "INSERT INTO items (label) VALUES ('hello');",
      );
      final result = await db.rawQuery('SELECT * FROM items;');
      expect(result.rows.first['label'], equals('hello'));
    });
  });

  group('SqliteDatabase - DbResult', () {
    test('first returns null for empty result', () async {
      final result = await db.select('users');
      expect(result.first, isNull);
    });

    test('first returns first row when not empty', () async {
      await db.insert('users', {'name': 'Alice', 'email': 'a@a.com'});
      final result = await db.select('users');
      expect(result.first, isNotNull);
      expect(result.first!['name'], equals('Alice'));
    });

    test('isEmpty and isNotEmpty reflect row count', () async {
      final empty = await db.select('users');
      expect(empty.isEmpty, isTrue);
      expect(empty.isNotEmpty, isFalse);

      await db.insert('users', {'name': 'Alice', 'email': 'a@a.com'});
      final nonEmpty = await db.select('users');
      expect(nonEmpty.isEmpty, isFalse);
      expect(nonEmpty.isNotEmpty, isTrue);
    });
  });

  group('SqliteDatabase - transaction', () {
    test('commits on success', () async {
      await db.transaction((tx) async {
        await tx.insert('users', {'name': 'Alice', 'email': 'a@a.com'});
        await tx.insert('users', {'name': 'Bob', 'email': 'b@b.com'});
      });
      final result = await db.select('users');
      expect(result.rows.length, equals(2));
    });

    test('rolls back on exception', () async {
      try {
        await db.transaction((tx) async {
          await tx.insert('users', {'name': 'Alice', 'email': 'a@a.com'});
          throw Exception('forced failure');
        });
        // ignore: empty_catches
      } catch (_) {}
      final result = await db.select('users');
      expect(result.rows, isEmpty);
    });

    test('transaction returns value from callback', () async {
      final id = await db.transaction((tx) async {
        final result =
            await tx.insert('users', {'name': 'Charlie', 'email': 'c@c.com'});
        return result.insertId;
      });
      expect(id, isNotNull);
    });

    test('select inside transaction sees its own writes', () async {
      await db.transaction((tx) async {
        await tx.insert('users', {'name': 'Dave', 'email': 'd@d.com'});
        final result = await tx.select('users');
        expect(result.rows.length, equals(1));
      });
    });
  });

  group('MigrationRunner', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dartapi_migrations_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('creates _dartapi_migrations table and applies pending files', () async {
      File('${tempDir.path}/0001_create_items.sql').writeAsStringSync(
        'CREATE TABLE items (id INTEGER PRIMARY KEY, label TEXT);',
      );
      File('${tempDir.path}/0002_add_price.sql').writeAsStringSync(
        'ALTER TABLE items ADD COLUMN price REAL DEFAULT 0;',
      );

      final runner = MigrationRunner(db, migrationsPath: tempDir.path);
      await runner.migrate();

      final applied = await runner.appliedMigrations();
      expect(applied, containsAll(['0001_create_items.sql', '0002_add_price.sql']));

      // Table was created
      final items = await db.rawQuery('SELECT * FROM items;');
      expect(items.rows, isEmpty);
    });

    test('skips already-applied migrations', () async {
      File('${tempDir.path}/0001_create_items.sql').writeAsStringSync(
        'CREATE TABLE items (id INTEGER PRIMARY KEY, label TEXT);',
      );

      final runner = MigrationRunner(db, migrationsPath: tempDir.path);
      await runner.migrate();
      await runner.migrate(); // second call should be a no-op

      final applied = await runner.appliedMigrations();
      expect(applied.length, equals(1));
    });

    test('applies only new migrations on second run', () async {
      File('${tempDir.path}/0001_create_items.sql').writeAsStringSync(
        'CREATE TABLE items (id INTEGER PRIMARY KEY, label TEXT);',
      );
      final runner = MigrationRunner(db, migrationsPath: tempDir.path);
      await runner.migrate();

      File('${tempDir.path}/0002_add_price.sql').writeAsStringSync(
        'ALTER TABLE items ADD COLUMN price REAL DEFAULT 0;',
      );
      await runner.migrate();

      final applied = await runner.appliedMigrations();
      expect(applied.length, equals(2));
    });

    test('throws StateError when migrations directory does not exist', () async {
      final runner = MigrationRunner(db, migrationsPath: '/nonexistent/path');
      expect(() => runner.migrate(), throwsA(isA<StateError>()));
    });
  });
}
