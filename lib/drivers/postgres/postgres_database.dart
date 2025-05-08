import 'package:postgres/postgres.dart';

import '../../core/sql_database.dart';
import '../../core/db_result.dart';

/// A concrete implementation of [SqlDatabase] for PostgreSQL.
///
/// Uses the `postgres` package to interact with a PostgreSQL database
/// and supports parameterized SQL queries with proper substitution.
///
/// All data manipulation methods (insert, update, delete) use `RETURNING *`
/// to return the affected rows.
class PostgresDatabase extends SqlDatabase {
  /// The underlying PostgreSQL connection instance.
  late final PostgreSQLConnection _connection;

  /// Creates a [PostgresDatabase] using the given [config].
  PostgresDatabase(super.config);

  /// Opens a connection to the PostgreSQL database.
  @override
  Future<void> connect() async {
    _connection = PostgreSQLConnection(
      config.host,
      config.port,
      config.database,
      username: config.username,
      password: config.password,
    );
    await _connection.open();
  }

  /// Closes the connection to the PostgreSQL database.
  @override
  Future<void> close() async {
    await _connection.close();
  }

  /// Executes a raw SQL query using PostgreSQL's named parameter syntax.
  ///
  /// - [query]: The SQL statement to execute.
  /// - [values]: Optional named parameters (e.g., `@id`, `@name`).
  /// Returns a [DbResult] with query results and execution time.
  @override
  Future<DbResult> rawQuery(
    String query, {
    Map<String, dynamic>? values,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      final result = await _connection.mappedResultsQuery(
        query,
        substitutionValues: values,
      );

      return DbResult(
        rows: result.map((row) => row.values.first).toList(),
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      throw Exception('PostgreSQL query failed: $e');
    }
  }

  /// Executes an INSERT query and returns the inserted row(s).
  ///
  /// Uses parameterized query substitution and `RETURNING *`.
  @override
  Future<DbResult> insert(String table, Map<String, dynamic> data) async {
    final columns = data.keys.join(', ');
    final values = data.keys.map((k) => '@$k').join(', ');
    final query = 'INSERT INTO $table ($columns) VALUES ($values) RETURNING *;';
    return rawQuery(query, values: data);
  }

  /// Executes an UPDATE query and returns the updated row(s).
  ///
  /// [data] contains the columns to update.
  /// [where] defines the filter conditions, with keys prefixed as `w_` internally.
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

  /// Executes a DELETE query and returns the deleted row(s).
  ///
  /// [where] defines the filter conditions to identify rows to delete.
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
