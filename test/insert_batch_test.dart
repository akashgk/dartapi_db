import 'package:dartapi_db/dartapi_db.dart';
import 'package:test/test.dart';

void main() {
  late SqliteDatabase db;

  setUp(() async {
    db = SqliteDatabase(DbConfig.sqlite(':memory:'));
    await db.connect();
    await db.rawQuery('''
      CREATE TABLE products (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        name  TEXT    NOT NULL,
        price REAL    NOT NULL
      );
    ''');
  });

  tearDown(() async => db.close());

  group('SqliteDatabase.insertBatch', () {
    test('inserts multiple rows', () async {
      await db.insertBatch('products', [
        {'name': 'Widget', 'price': 9.99},
        {'name': 'Gadget', 'price': 19.99},
        {'name': 'Doohickey', 'price': 4.99},
      ]);
      final result = await db.select('products');
      expect(result.rows, hasLength(3));
    });

    test('returns empty DbResult for empty list', () async {
      final result = await db.insertBatch('products', []);
      expect(result.rows, isEmpty);
      expect(result.affectedRows, equals(0));
    });

    test('inserted values are correct', () async {
      await db.insertBatch('products', [
        {'name': 'Alpha', 'price': 1.0},
        {'name': 'Beta', 'price': 2.0},
      ]);
      final result = await db.select('products');
      final names = result.rows.map((r) => r['name']).toList();
      expect(names, containsAll(['Alpha', 'Beta']));
    });

    test('works inside a transaction', () async {
      await db.transaction((tx) async {
        await tx.insertBatch('products', [
          {'name': 'TxA', 'price': 10.0},
          {'name': 'TxB', 'price': 20.0},
        ]);
      });
      final result = await db.select('products');
      expect(result.rows, hasLength(2));
    });

    test('transaction rolls back on error', () async {
      try {
        await db.transaction((tx) async {
          await tx.insertBatch('products', [
            {'name': 'Good', 'price': 5.0},
          ]);
          throw Exception('forced rollback');
        });
      } catch (_) {}
      final result = await db.select('products');
      expect(result.rows, isEmpty);
    });
  });

  group('DbResult.map and firstAs', () {
    setUp(() async {
      await db.insertBatch('products', [
        {'name': 'Widget', 'price': 9.99},
        {'name': 'Gadget', 'price': 19.99},
      ]);
    });

    test('map converts rows to typed list', () async {
      final result = await db.select('products');
      final names = result.map((r) => r['name'] as String);
      expect(names, containsAll(['Widget', 'Gadget']));
    });

    test('firstAs returns first row mapped', () async {
      final result = await db.select('products');
      final name = result.firstAs((r) => r['name'] as String);
      expect(name, isNotNull);
      expect(['Widget', 'Gadget'], contains(name));
    });

    test('firstAs returns null on empty result', () async {
      final result = await db.select('products', where: {'name': 'nonexistent'});
      expect(result.firstAs((r) => r['name']), isNull);
    });
  });
}
