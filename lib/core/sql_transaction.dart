import 'dartapi_db_core.dart';
import 'db_result.dart';
import 'db_transaction.dart';

/// An abstract base class for transaction-scoped SQL operations.
///
/// Mirrors the placeholder-aware SQL building of [SqlDatabase] but for use
/// inside a [DbTransaction]. Subclasses implement [rawQuery] and declare
/// their [paramStyle].
abstract class SqlTransaction implements DbTransaction {
  DbParamStyle get paramStyle;

  String ph(String key) => paramStyle == DbParamStyle.colon ? ':$key' : '@$key';

  @override
  Future<DbResult> insert(String table, Map<String, dynamic> data) async {
    final columns = data.keys.join(', ');
    final placeholders = data.keys.map(ph).join(', ');
    return rawQuery(
      'INSERT INTO $table ($columns) VALUES ($placeholders);',
      values: data,
    );
  }

  @override
  Future<DbResult> select(String table, {Map<String, dynamic>? where}) async {
    var query = 'SELECT * FROM $table';
    final params = <String, dynamic>{};
    if (where != null && where.isNotEmpty) {
      final conditions = where.entries
          .map((e) => '${e.key} = ${ph(e.key)}')
          .join(' AND ');
      query += ' WHERE $conditions';
      params.addAll(where);
    }
    return rawQuery(query, values: params.isEmpty ? null : params);
  }

  @override
  Future<DbResult> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> where,
  }) async {
    final sets = data.keys.map((k) => '$k = ${ph(k)}').join(', ');
    final conditions = where.keys
        .map((k) => '$k = ${ph('w_$k')}')
        .join(' AND ');
    final values = {
      ...data,
      ...{for (final k in where.keys) 'w_$k': where[k]},
    };
    return rawQuery(
      'UPDATE $table SET $sets WHERE $conditions;',
      values: values,
    );
  }

  @override
  Future<DbResult> delete(
    String table, {
    required Map<String, dynamic> where,
  }) async {
    final conditions = where.keys.map((k) => '$k = ${ph(k)}').join(' AND ');
    return rawQuery('DELETE FROM $table WHERE $conditions;', values: where);
  }

  @override
  Future<DbResult> insertBatch(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return const DbResult(rows: [], affectedRows: 0);
    final columns = rows.first.keys.toList();
    final colList = columns.join(', ');
    final valueSets = <String>[];
    final params = <String, dynamic>{};
    for (var i = 0; i < rows.length; i++) {
      final keys = columns.map((c) => 'r${i}_$c').toList();
      valueSets.add('(${keys.map(ph).join(', ')})');
      for (final col in columns) {
        params['r${i}_$col'] = rows[i][col];
      }
    }
    return rawQuery(
      'INSERT INTO $table ($colList) VALUES ${valueSets.join(', ')};',
      values: params,
    );
  }
}
