import 'package:sqlite3/sqlite3.dart';

import '../../core/dartapi_db_core.dart';
import '../../core/db_result.dart';
import '../../core/db_transaction.dart';
import '../../types/db_config.dart';

/// A SQLite implementation of [DartApiDB] using the `sqlite3` package.
///
/// [DbConfig.database] is the file path to the SQLite database file.
/// Use `':memory:'` for an ephemeral in-memory database.
///
/// ```dart
/// final db = await DatabaseFactory.create(DbConfig.sqlite('app.db'));
/// // or in-memory:
/// final db = await DatabaseFactory.create(DbConfig.sqlite(':memory:'));
/// ```
///
/// **Note:** SQLite uses positional `?` parameters. Pass values in insertion
/// order matching the `?` placeholders in your query.
class SqliteDatabase implements DartApiDB {
  final DbConfig config;
  late final Database _db;

  SqliteDatabase(this.config);

  @override
  DbParamStyle get paramStyle => DbParamStyle.positional;

  @override
  Future<void> connect() async {
    _db = sqlite3.open(config.database);
  }

  @override
  Future<void> close() async => _db.close();

  @override
  Future<DbResult> rawQuery(
    String query, {
    Map<String, dynamic>? values,
  }) async => _run(_db, query, values);

  @override
  Future<DbResult> insert(String table, Map<String, dynamic> data) async {
    final columns = data.keys.join(', ');
    final placeholders = List.filled(data.length, '?').join(', ');
    return _run(
      _db,
      'INSERT INTO $table ($columns) VALUES ($placeholders);',
      data,
    );
  }

  @override
  Future<DbResult> select(String table, {Map<String, dynamic>? where}) async {
    if (where == null || where.isEmpty) {
      return _run(_db, 'SELECT * FROM $table;', null);
    }
    final cond = where.keys.map((k) => '$k = ?').join(' AND ');
    return _run(_db, 'SELECT * FROM $table WHERE $cond;', where);
  }

  @override
  Future<DbResult> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> where,
  }) async {
    final sets = data.keys.map((k) => '$k = ?').join(', ');
    final cond = where.keys.map((k) => '$k = ?').join(' AND ');
    final values = {...data, ...where}; // SET values first, WHERE values after
    return _run(_db, 'UPDATE $table SET $sets WHERE $cond;', values);
  }

  @override
  Future<DbResult> delete(
    String table, {
    required Map<String, dynamic> where,
  }) async {
    final cond = where.keys.map((k) => '$k = ?').join(' AND ');
    return _run(_db, 'DELETE FROM $table WHERE $cond;', where);
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(DbTransaction tx) callback,
  ) async {
    _db.execute('BEGIN');
    try {
      final result = await callback(_SqliteTxDB(_db));
      _db.execute('COMMIT');
      return result;
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }
}

/// A [DbTransaction] backed by a [Database] inside an active transaction.
class _SqliteTxDB implements DbTransaction {
  final Database _db;
  _SqliteTxDB(this._db);

  @override
  Future<DbResult> rawQuery(
    String query, {
    Map<String, dynamic>? values,
  }) async => _run(_db, query, values);

  @override
  Future<DbResult> insert(String table, Map<String, dynamic> data) async {
    final columns = data.keys.join(', ');
    final placeholders = List.filled(data.length, '?').join(', ');
    return _run(
      _db,
      'INSERT INTO $table ($columns) VALUES ($placeholders);',
      data,
    );
  }

  @override
  Future<DbResult> select(String table, {Map<String, dynamic>? where}) async {
    if (where == null || where.isEmpty) {
      return _run(_db, 'SELECT * FROM $table;', null);
    }
    final cond = where.keys.map((k) => '$k = ?').join(' AND ');
    return _run(_db, 'SELECT * FROM $table WHERE $cond;', where);
  }

  @override
  Future<DbResult> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> where,
  }) async {
    final sets = data.keys.map((k) => '$k = ?').join(', ');
    final cond = where.keys.map((k) => '$k = ?').join(' AND ');
    return _run(_db, 'UPDATE $table SET $sets WHERE $cond;', {
      ...data,
      ...where,
    });
  }

  @override
  Future<DbResult> delete(
    String table, {
    required Map<String, dynamic> where,
  }) async {
    final cond = where.keys.map((k) => '$k = ?').join(' AND ');
    return _run(_db, 'DELETE FROM $table WHERE $cond;', where);
  }
}

/// Executes [query] against [db] and returns a [DbResult].
///
/// [values] are passed positionally in map insertion order.
DbResult _run(Database db, String query, Map<String, dynamic>? values) {
  final params = values?.values.cast<Object?>().toList() ?? <Object?>[];
  final trimmed = query.trimLeft().toUpperCase();
  final isQuery =
      trimmed.startsWith('SELECT') ||
      trimmed.startsWith('PRAGMA') ||
      trimmed.startsWith('WITH');

  if (isQuery) {
    final result = db.select(query, params);
    return DbResult(
      rows: result.map((row) => _rowToMap(row, result.columnNames)).toList(),
      affectedRows: result.length,
    );
  } else {
    db.execute(query, params);
    return DbResult(
      rows: [],
      affectedRows: db.updatedRows,
      insertId: db.lastInsertRowId,
    );
  }
}

Map<String, dynamic> _rowToMap(Row row, List<String> columnNames) {
  final map = <String, dynamic>{};
  for (var i = 0; i < columnNames.length; i++) {
    map[columnNames[i]] = row.columnAt(i);
  }
  return map;
}
