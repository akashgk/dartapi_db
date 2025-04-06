import 'package:postgres/postgres.dart';

import '../../core/sql_database.dart';
import '../../core/db_result.dart';

class PostgresDatabase extends SqlDatabase {
  late final PostgreSQLConnection _connection;

  PostgresDatabase(super.config);

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

  @override
  Future<void> close() async {
    await _connection.close();
  }

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

  @override
  Future<DbResult> insert(String table, Map<String, dynamic> data) async {
    final columns = data.keys.join(', ');
    final values = data.keys.map((k) => '@$k').join(', ');
    final query = 'INSERT INTO $table ($columns) VALUES ($values) RETURNING *;';
    return rawQuery(query, values: data);
  }

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
