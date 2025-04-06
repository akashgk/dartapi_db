import 'package:mysql_client_plus/mysql_client_plus.dart';
import '../../types/db_config.dart';
import '../../core/dartapi_db_core.dart';
import '../../core/db_result.dart';

class MySqlDatabase implements DartApiDB {
  final DbConfig config;
  late final MySQLConnection _connection;

  MySqlDatabase(this.config);

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

  @override
  Future<void> close() async {
    await _connection.close();
  }

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

  @override
  Future<DbResult> insert(String table, Map<String, dynamic> data) async {
    final columns = data.keys.join(', ');
    final placeholders = data.keys.map((k) => ':$k').join(', ');
    final query = 'INSERT INTO $table ($columns) VALUES ($placeholders);';
    return rawQuery(query, values: data);
  }

  @override
  Future<DbResult> select(String table, {Map<String, dynamic>? where}) async {
    var query = 'SELECT * FROM $table';
    if (where != null && where.isNotEmpty) {
      final conditions = where.keys.map((k) => '$k = :$k').join(' AND ');
      query += ' WHERE $conditions';
    }
    return rawQuery(query, values: where);
  }

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
