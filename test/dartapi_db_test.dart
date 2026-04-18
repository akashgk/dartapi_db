import 'package:dartapi_db/core/dartapi_db_core.dart';
import 'package:dartapi_db/factory/database_factory.dart';
import 'package:dartapi_db/types/db_config.dart';
import 'package:dartapi_db/types/db_type.dart';
import 'package:dartapi_db/types/pool_config.dart';
import 'package:test/test.dart';

void main() {
  group('PoolConfig', () {
    test('has correct default values', () {
      const pool = PoolConfig();
      expect(pool.maxConnections, equals(10));
      expect(pool.minConnections, equals(2));
      expect(pool.connectionTimeout, equals(const Duration(seconds: 30)));
      expect(pool.idleTimeout, equals(const Duration(minutes: 10)));
    });

    test('custom values are preserved', () {
      const pool = PoolConfig(
        maxConnections: 5,
        minConnections: 1,
        connectionTimeout: Duration(seconds: 10),
        idleTimeout: Duration(minutes: 5),
      );
      expect(pool.maxConnections, equals(5));
      expect(pool.minConnections, equals(1));
      expect(pool.connectionTimeout, equals(const Duration(seconds: 10)));
      expect(pool.idleTimeout, equals(const Duration(minutes: 5)));
    });

    test('DbConfig without poolConfig is backward compatible', () {
      const config = DbConfig(
        type: DbType.postgres,
        host: 'localhost',
        port: 5432,
        database: 'test',
        username: 'postgres',
        password: 'password',
      );
      expect(config.poolConfig, isNull);
    });

    test('DbConfig with poolConfig stores it correctly', () {
      const pool = PoolConfig(maxConnections: 20);
      const config = DbConfig(
        type: DbType.postgres,
        host: 'localhost',
        port: 5432,
        database: 'test',
        username: 'postgres',
        password: 'password',
        poolConfig: pool,
      );
      expect(config.poolConfig!.maxConnections, equals(20));
    });
  });

  group('Postgres Integration Test', () {
    late DartApiDB db;
    int? insertedId;

    setUpAll(() async {
      final config = DbConfig(
        type: DbType.postgres,
        host: 'localhost',
        port: 5432,
        database: 'dartapi_test',
        username: 'postgres',
        password: 'yourpassword',
      );
      db = await DatabaseFactory.create(config);

      await db.rawQuery(
        'CREATE TABLE IF NOT EXISTS test_users (id SERIAL PRIMARY KEY, name TEXT NOT NULL, email TEXT NOT NULL);',
      );
    });

    test('Insert works correctly', () async {
      final result = await db.insert('test_users', {
        'name': 'Test User',
        'email': 'test@example.com',
      });

      expect(result.isNotEmpty, true);
      insertedId = result.first?['id'];
    });

    test('Select works correctly', () async {
      final result = await db.select('test_users');
      expect(result.rows.any((row) => row['id'] == insertedId), true);
    });

    test('Update works correctly', () async {
      final result = await db.update(
        'test_users',
        {'name': 'Updated User'},
        where: {'id': insertedId},
      );

      expect(result.first?['name'], equals('Updated User'));
    });

    test('Delete works correctly', () async {
      final result = await db.delete('test_users', where: {'id': insertedId});

      expect(result.isNotEmpty, true);
    });

    tearDownAll(() async {
      await db.rawQuery('DROP TABLE IF EXISTS test_users;');
      await db.close();
    });
  });

  group('Postgres Pool Integration Test', () {
    late DartApiDB db;

    setUpAll(() async {
      final config = DbConfig(
        type: DbType.postgres,
        host: 'localhost',
        port: 5432,
        database: 'dartapi_test',
        username: 'postgres',
        password: 'yourpassword',
        poolConfig: const PoolConfig(maxConnections: 3, minConnections: 1),
      );
      db = await DatabaseFactory.create(config);
      await db.rawQuery(
        'CREATE TABLE IF NOT EXISTS pool_test (id SERIAL PRIMARY KEY, val TEXT);',
      );
    });

    test('handles 5 concurrent inserts against pool of size 3', () async {
      final results = await Future.wait(
        List.generate(5, (i) => db.insert('pool_test', {'val': 'item_$i'})),
      );
      expect(results.length, equals(5));
      expect(results.every((r) => r.isNotEmpty), isTrue);
    });

    test('select returns all inserted rows', () async {
      final result = await db.select('pool_test');
      expect(result.rows.length, greaterThanOrEqualTo(5));
    });

    tearDownAll(() async {
      await db.rawQuery('DROP TABLE IF EXISTS pool_test;');
      await db.close();
    });
  });
}
