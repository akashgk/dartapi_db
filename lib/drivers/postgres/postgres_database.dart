import 'package:postgres/postgres.dart';
import '../../core/sql_database.dart';
import '../../core/db_result.dart';

/// A PostgreSQL implementation of [SqlDatabase] using the `postgres` package.
///
/// This class allows you to perform standard SQL operations such as querying,
/// inserting, updating, and deleting data in a PostgreSQL database using
/// named parameters and Dart-friendly types.
class PostgresDatabase extends SqlDatabase {
  /// Internal PostgreSQL connection instance.
  late final Connection _connection;

  /// Creates a [PostgresDatabase] with the provided [config] settings.
  PostgresDatabase(super.config);

  /// Opens a connection to the PostgreSQL database using the configured endpoint.
  ///
  /// SSL is disabled by default. Modify [ConnectionSettings] if needed.
  @override
  Future<void> connect() async {
    _connection = await Connection.open(
      Endpoint(
        host: config.host,
        database: config.database,
        port: config.port,
        username: config.username,
        password: config.password,
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );
  }

  /// Closes the current PostgreSQL database connection.
  @override
  Future<void> close() async {
    await _connection.close();
  }

  /// Executes a raw SQL query with optional named parameters.
  ///
  /// If [values] is non-empty, the query is parsed using [Sql.named].
  /// Otherwise, a raw [Sql] query is executed.
  ///
  /// Returns a [DbResult] containing the resulting rows and query time.
  @override
  Future<DbResult> rawQuery(
    String query, {
    Map<String, dynamic>? values,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();

      final result = values != null && values.isNotEmpty
          ? await _connection.execute(Sql.named(query), parameters: values)
          : await _connection.execute(Sql(query));

      final rows = result.map((row) => row.toColumnMap()).toList();

      return DbResult(
        rows: rows,
        affectedRows: rows.length,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      throw Exception('PostgreSQL query failed: $e');
    }
  }

  /// Inserts a new row into the specified [table] and returns the inserted data.
  ///
  /// Automatically generates a parameterized query using the [data] keys.
  /// Uses `RETURNING *` to fetch and return the inserted row(s).
  @override
  Future<DbResult> insert(String table, Map<String, dynamic> data) async {
    final columns = data.keys.join(', ');
    final values = data.keys.map((k) => '@$k').join(', ');
    final query = 'INSERT INTO $table ($columns) VALUES ($values) RETURNING *;';
    return rawQuery(query, values: data);
  }

  /// Updates matching rows in the [table] with the given [data].
  ///
  /// The [where] clause is used to filter which rows are updated.
  /// All keys in [where] are prefixed with `w_` to avoid naming collisions.
  ///
  /// Returns the updated row(s).
  @override
  Future<DbResult> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> where,
  }) async {
    final sets = data.keys.map((k) => '$k = @$k').join(', ');
    final conditions = where.keys.map((k) => '$k = @w_$k').join(' AND ');

    final values = {
      ...data,
      ...{for (var k in where.keys) 'w_$k': where[k]},
    };

    final query = 'UPDATE $table SET $sets WHERE $conditions RETURNING *;';
    return rawQuery(query, values: values);
  }

  /// Deletes rows from the specified [table] based on the [where] clause.
  ///
  /// Returns the deleted row(s).
  @override
  Future<DbResult> delete(
    String table, {
    required Map<String, dynamic> where,
  }) async {
    final conditions = where.keys.map((k) => '$k = @$k').join(' AND ');
    final query = 'DELETE FROM $table WHERE $conditions RETURNING *;';
    return rawQuery(query, values: where);
  }
}