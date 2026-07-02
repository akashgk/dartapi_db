import 'package:dartapi_db/dartapi_db.dart';
import 'package:test/test.dart';

void main() {
  group('DartApiDB.ping', () {
    test('returns true for a healthy connection', () async {
      final db = await DatabaseFactory.create(DbConfig.sqlite(':memory:'));
      expect(await db.ping(), isTrue);
      await db.close();
    });

    test(
      'returns false instead of throwing once the connection is closed',
      () async {
        final db = await DatabaseFactory.create(DbConfig.sqlite(':memory:'));
        await db.close();
        expect(await db.ping(), isFalse);
      },
    );
  });
}
