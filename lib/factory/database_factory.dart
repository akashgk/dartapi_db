import 'package:dartapi_db/drivers/postgres/postgres_database.dart';

import '../core/dartapi_db_core.dart';
import '../types/db_config.dart';
import '../types/db_type.dart';

class DatabaseFactory {
  const DatabaseFactory._(); // Prevent instantiation

  /// Dynamically instantiates the correct driver
  static Future<DartApiDB> create(DbConfig config) async {
    late final DartApiDB db;

    switch (config.type) {
      case DbType.postgres:
        db = PostgresDatabase(config);
        break;

      case DbType.mysql:
        throw UnimplementedError('MySQL support is not implemented yet.');
    }

    await db.connect();
    return db;
  }
}
