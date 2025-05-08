import 'package:dartapi_db/drivers/mysql/mysql_database.dart';
import 'package:dartapi_db/drivers/postgres/postgres_database.dart';

import '../core/dartapi_db_core.dart';
import '../types/db_config.dart';
import '../types/db_type.dart';

/// A factory class responsible for instantiating the correct database driver
/// based on the provided [DbConfig].
///
/// This abstracts away the database-specific implementation behind the
/// [DartApiDB] interface, allowing you to switch between drivers
/// without changing your application logic.
///
/// Currently supported:
/// - PostgreSQL (`DbType.postgres`)
/// - MySQL (`DbType.mysql`)
class DatabaseFactory {
  /// Private constructor to prevent instantiation.
  const DatabaseFactory._();

  /// Creates and returns an instance of [DartApiDB] based on the provided [config].
  ///
  /// Automatically selects the appropriate database driver based on [DbType].
  /// After instantiation, the database connection is established by calling `connect()`.
  ///
  /// Throws [UnsupportedError] if the provided [DbType] is not supported.
  static Future<DartApiDB> create(DbConfig config) async {
    late final DartApiDB db;

    switch (config.type) {
      case DbType.postgres:
        db = PostgresDatabase(config);
        break;
      case DbType.mysql:
        db = MySqlDatabase(config);
        break;
    }

    await db.connect();
    return db;
  }
}
