import '../types/db_config.dart';
import 'dartapi_db_core.dart';
import 'db_result.dart';

abstract class SqlDatabase implements DartApiDB {
  final DbConfig config;

  SqlDatabase(this.config);

  @override
  Future<DbResult> insert(String table, Map<String, dynamic> data) async {
    final columns = data.keys.join(', ');
    final values = data.keys.map((k) => '@$k').join(', ');
    final query = 'INSERT INTO $table ($columns) VALUES ($values);';
    return rawQuery(query, values: data);
  }

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

  @override
  Future<DbResult> delete(
    String table, {
    required Map<String, dynamic> where,
  }) async {
    final conditions = where.keys.map((k) => '$k = @$k').join(' AND ');
    final query = 'DELETE FROM $table WHERE $conditions;';
    return rawQuery(query, values: where);
  }

  @override
  Future<DbResult> rawQuery(String query, {Map<String, dynamic>? values});
}
