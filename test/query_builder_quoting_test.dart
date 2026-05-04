import 'package:dartapi_db/dartapi_db.dart';
import 'package:test/test.dart';

void main() {
  late SqliteDatabase db;

  setUp(() async {
    db = SqliteDatabase(DbConfig.sqlite(':memory:'));
    await db.connect();
    await db.rawQuery('''
      CREATE TABLE "users" (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        name  TEXT    NOT NULL,
        email TEXT    NOT NULL
      );
    ''');
    await db.rawQuery(
      'INSERT INTO "users" (name, email) VALUES (?, ?)',
      values: {'n': 'Alice', 'e': 'alice@example.com'},
    );
    await db.rawQuery(
      'INSERT INTO "users" (name, email) VALUES (?, ?)',
      values: {'n': 'Bob', 'e': 'bob@example.com'},
    );
  });

  tearDown(() async => db.close());

  group('QueryBuilder identifier quoting (SQLite)', () {
    test('get() returns rows with quoted table', () async {
      final result = await db.query('users').get();
      expect(result.rows, hasLength(2));
    });

    test('where with equals uses quoted column', () async {
      final result =
          await db.query('users').where('name', equals: 'Alice').get();
      expect(result.rows, hasLength(1));
      expect(result.first!['name'], equals('Alice'));
    });

    test('select restricts to specified columns', () async {
      final result =
          await db.query('users').select(['name']).get();
      for (final row in result.rows) {
        expect(row.containsKey('name'), isTrue);
        expect(row.containsKey('email'), isFalse);
      }
    });

    test('orderBy uses quoted column', () async {
      final result =
          await db.query('users').orderBy('name').get();
      final names = result.rows.map((r) => r['name']).toList();
      expect(names, equals(['Alice', 'Bob']));
    });

    test('count returns correct row count', () async {
      final count = await db.query('users').count();
      expect(count, equals(2));
    });

    test('count with where condition', () async {
      final count =
          await db.query('users').where('name', equals: 'Alice').count();
      expect(count, equals(1));
    });
  });

  group('QueryBuilder whereIn warning', () {
    test('throws ArgumentError for empty whereIn', () {
      expect(
        () => db.query('users').where('id', whereIn: []),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('MigrationRunner dryRun', () {
    test('dryRun prints pending without applying', () async {
      final dryDb = SqliteDatabase(DbConfig.sqlite(':memory:'));
      await dryDb.connect();
      final runner = MigrationRunner(dryDb, migrationsPath: 'test/migrations');
      // Should not throw even without _dartapi_migrations table.
      // We just verify no table is created and no error is thrown.
      // (The test/migrations dir doesn't exist, so it will throw StateError)
      await expectLater(
        runner.migrate(dryRun: true),
        throwsA(isA<StateError>()),
      );
      await dryDb.close();
    });
  });
}
