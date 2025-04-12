import 'package:dartapi_db/core/dartapi_db_core.dart';
import 'package:dartapi_db/factory/database_factory.dart';
import 'package:dartapi_db/types/db_config.dart';
import 'package:dartapi_db/types/db_type.dart';
import 'package:test/test.dart';

void main() {
  group('Postgres Integration Test', () {
    late DartApiDB db;
    int? insertedId;

    setUpAll(() async {
      final config = DbConfig(
        type: DbType.postgres,
        host: 'localhost',
        port: 5432,
        database: 'dartapi_test',
        username: 'postgres', // or the user you created
        password: 'yourpassword',
      );
      db = await DatabaseFactory.create(config);

      await db.rawQuery(
        "CREATE TABLE IF NOT EXISTS test_users (id SERIAL PRIMARY KEY, name TEXT NOT NULL, email TEXT NOT NULL);",
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
}
