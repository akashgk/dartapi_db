import 'package:mysql_client_plus/mysql_client_plus.dart';
import '../../types/db_config.dart';
import '../../core/dartapi_db_core.dart';
import '../../core/db_result.dart';

/// A concrete implementation of [DartApiDB] for MySQL databases.
///
/// Uses the `mysql_client_plus` package to interact with the database
/// and supports parameterized queries, inserts, updates, and deletions.
class MySqlDatabase implements DartApiDB {
  /// Configuration for connecting to the MySQL database.
  final DbConfig config;

  /// The underlying MySQL connection instance.
  late final MySQLConnection _connection;

  /// Creates a new [MySqlDatabase] using the given [config].
  MySqlDatabase(this.config);

  /// Opens the connection to the MySQL database.
  @override
  Future<void> connect() async {
    _connection = await MySQLConnection.createConnection(
      host: config.host,
      port: config.port,
      userName: config.username,
      password: config.password,
      databaseName: config.database,
    );
    await _connection.connect();
  }

  /// Closes the connection to the MySQL database.
  @override
  Future<void> close() async {
    await _connection.close();
  }

  /// Executes a raw SQL query using named parameter substitution.
  ///
  /// Returns a [DbResult] with the rows, affected row count, and insert ID.
  @override
  Future<DbResult> rawQuery(
    String query, {
    Map<String, dynamic>? values,
  }) async {
    final result = await _connection.execute(query, values ?? {});
    return DbResult(
      rows: result.rows.map((row) => row.assoc()).toList(),
      affectedRows: result.affectedRows.toInt(),
      insertId: result.lastInsertID,
    );
  }

  /// Executes an INSERT query into the specified [table].
  ///
  /// - [data]: A map of column names and values to insert.
  /// Returns the inserted row metadata.
  @override
  Future<DbResult> insert(String table, Map<String, dynamic> data) async {
    final columns = data.keys.join(', ');
    final placeholders = data.keys.map((k) => ':$k').join(', ');
    final query = 'INSERT INTO $table ($columns) VALUES ($placeholders);';
    return rawQuery(query, values: data);
  }

  /// Executes a SELECT query on the specified [table].
  ///
  /// - [where]: Optional filter criteria.
  /// Returns all matching rows.
  @override
  Future<DbResult> select(String table, {Map<String, dynamic>? where}) async {
    var query = 'SELECT * FROM $table';
    if (where != null && where.isNotEmpty) {
      final conditions = where.keys.map((k) => '$k = :$k').join(' AND ');
      query += ' WHERE $conditions';
    }
    return rawQuery(query, values: where);
  }

  /// Executes an UPDATE query on the specified [table].
  ///
  /// - [data]: Columns and values to update.
  /// - [where]: Conditions to match rows that should be updated.
  /// Returns the affected rows.
  @override
  Future<DbResult> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> where,
  }) async {
    final sets = data.keys.map((k) => '$k = :$k').join(', ');
    final conditions = where.keys.map((k) => '$k = :$k').join(' AND ');
    final query = 'UPDATE $table SET $sets WHERE $conditions;';
    return rawQuery(query, values: {...data, ...where});
  }

  /// Executes a DELETE query on the specified [table].
  ///
  /// - [where]: Conditions to match rows that should be deleted.
  /// Returns the affected rows.
  @override
  Future<DbResult> delete(
    String table, {
    required Map<String, dynamic> where,
  }) async {
    final conditions = where.keys.map((k) => '$k = :$k').join(' AND ');
    final query = 'DELETE FROM $table WHERE $conditions;';
    return rawQuery(query, values: where);
  }
}
