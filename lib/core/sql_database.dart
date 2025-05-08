import '../types/db_config.dart';
import 'dartapi_db_core.dart';
import 'db_result.dart';

/// An abstract base class for SQL-based database implementations.
///
/// This class provides shared implementations for common SQL operations like
/// `insert`, `select`, `update`, and `delete`. Concrete subclasses are expected
/// to implement the [rawQuery] method to execute the final query using the
/// underlying database client.
abstract class SqlDatabase implements DartApiDB {
  /// Configuration settings for the database connection.
  final DbConfig config;

  /// Creates a new SQL database instance with the provided [config].
  SqlDatabase(this.config);

  /// Executes an INSERT query and returns the result.
  ///
  /// Automatically formats the columns and values as placeholders for parameterized execution.
  @override
  Future<DbResult> insert(String table, Map<String, dynamic> data) async {
    final columns = data.keys.join(', ');
    final values = data.keys.map((k) => '@$k').join(', ');
    final query = 'INSERT INTO $table ($columns) VALUES ($values);';
    return rawQuery(query, values: data);
  }

  /// Executes a SELECT query with optional WHERE, LIMIT, and OFFSET clauses.
  ///
  /// Returns all matching rows from the specified [table].
  @override
  Future<DbResult> select(
    String table, {
    Map<String, dynamic>? where,
    int? limit,
    int? offset,
  }) async {
    var query = 'SELECT * FROM $table';
    final values = <String, dynamic>{};

    if (where != null && where.isNotEmpty) {
      final conditions = where.entries
          .map((e) => '${e.key} = @${e.key}')
          .join(' AND ');
      query += ' WHERE $conditions';
      values.addAll(where);
    }

    if (limit != null) query += ' LIMIT $limit';
    if (offset != null) query += ' OFFSET $offset';

    return rawQuery(query, values: values);
  }

  /// Executes an UPDATE query with a required WHERE clause.
  ///
  /// Updates values in the [table] where the [where] conditions are met.
  /// Uses prefixed parameters (e.g., `@w_key`) to avoid naming conflicts.
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

    final query = 'UPDATE $table SET $sets WHERE $conditions;';
    return rawQuery(query, values: values);
  }

  /// Executes a DELETE query with a required WHERE clause.
  ///
  /// Deletes rows in the [table] that match the [where] conditions.
  @override
  Future<DbResult> delete(
    String table, {
    required Map<String, dynamic> where,
  }) async {
    final conditions = where.keys.map((k) => '$k = @$k').join(' AND ');
    final query = 'DELETE FROM $table WHERE $conditions;';
    return rawQuery(query, values: where);
  }

  /// Executes a raw SQL query.
  ///
  /// This method must be implemented by the concrete subclass.
  /// [values] can be used for named parameter substitution.
  @override
  Future<DbResult> rawQuery(String query, {Map<String, dynamic>? values});
}
