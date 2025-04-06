import 'package:dartapi_db/dartapi_db.dart';

void main() async {
  final config = DbConfig(
    type: DbType.postgres,
    host: 'localhost',
    port: 5432,
    database: 'dartapi_test',
    username: 'postgres', // or the user you created
    password: 'postgres',
  );
  final db = await DatabaseFactory.create(config);

  await db.insert('users', {'name': 'Akash', 'email': 'akash@example.com'});

  final result = await db.select('users');

  print(result.rows);
}
