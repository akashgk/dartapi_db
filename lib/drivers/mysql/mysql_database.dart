import 'package:mysql_client_plus/mysql_client_plus.dart';
import '../../types/db_config.dart';
import '../../types/pool_config.dart';
import '../../core/dartapi_db_core.dart';
import '../../core/db_result.dart';
import '../../core/db_transaction.dart';

/// A concrete implementation of [DartApiDB] for MySQL databases.
///
/// Uses [MySQLConnectionPool] from `mysql_client_plus` to manage concurrent
/// connections. [PoolConfig.minConnections] and [PoolConfig.idleTimeout] are
/// not supported by the underlying pool and are silently ignored.
class MySqlDatabase implements DartApiDB {
  final DbConfig config;
  late final MySQLConnectionPool _pool;

  MySqlDatabase(this.config);

  PoolConfig get _poolConfig => config.poolConfig ?? const PoolConfig();

  @override
  DbParamStyle get paramStyle => DbParamStyle.colon;

  /// Creates the MySQL connection pool.
  ///
  /// The pool is lazy — connections are opened on first use.
  @override
  Future<void> connect() async {
    _pool = MySQLConnectionPool(
      host: config.host,
      port: config.port,
      userName: config.username,
      password: config.password,
      databaseName: config.database,
      maxConnections: _poolConfig.maxConnections,
      secure: false,
      timeoutMs: _poolConfig.connectionTimeout.inMilliseconds,
    );
  }

  /// Closes all connections in the pool.
  @override
  Future<void> close() async => _pool.close();

  /// Executes a raw SQL query using named parameter substitution.
  ///
  /// Returns a [DbResult] with the rows, affected row count, and insert ID.
  @override
  Future<DbResult> rawQuery(
    String query, {
    Map<String, dynamic>? values,
  }) async {
    final result = await _pool.execute(query, values ?? {});
    return DbResult(
      rows: result.rows.map((row) => row.assoc()).toList(),
      affectedRows: result.affectedRows.toInt(),
      insertId: result.lastInsertID,
    );
  }

  /// Executes an INSERT query into the specified [table].
  @override
  Future<DbResult> insert(String table, Map<String, dynamic> data) async {
    final columns = data.keys.join(', ');
    final placeholders = data.keys.map((k) => ':$k').join(', ');
    final query = 'INSERT INTO $table ($columns) VALUES ($placeholders);';
    return rawQuery(query, values: data);
  }

  /// Executes a SELECT query on the specified [table].
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
  /// Keys in [where] are prefixed with `w_` to avoid naming collisions.
  @override
  Future<DbResult> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> where,
  }) async {
    final sets = data.keys.map((k) => '$k = :$k').join(', ');
    final conditions = where.keys.map((k) => '$k = :w_$k').join(' AND ');
    final whereParams = {for (var k in where.keys) 'w_$k': where[k]};
    return rawQuery(
      'UPDATE $table SET $sets WHERE $conditions;',
      values: {...data, ...whereParams},
    );
  }

  /// Executes a DELETE query on the specified [table].
  @override
  Future<DbResult> delete(
    String table, {
    required Map<String, dynamic> where,
  }) async {
    final conditions = where.keys.map((k) => '$k = :$k').join(' AND ');
    return rawQuery(
      'DELETE FROM $table WHERE $conditions;',
      values: where,
    );
  }

  /// Runs [callback] inside a MySQL transaction.
  ///
  /// Acquires a dedicated connection from the pool and issues
  /// `START TRANSACTION`, then `COMMIT` or `ROLLBACK`.
  @override
  Future<T> transaction<T>(Future<T> Function(DbTransaction tx) callback) async {
    late T result;
    await _pool.withConnection((conn) async {
      await conn.execute('START TRANSACTION');
      try {
        result = await callback(_MySqlTxDB(conn));
        await conn.execute('COMMIT');
      } catch (e) {
        await conn.execute('ROLLBACK');
        rethrow;
      }
    });
    return result;
  }
}

/// A [DbTransaction] implementation backed by a single [MySQLConnection].
class _MySqlTxDB implements DbTransaction {
  final MySQLConnection _conn;

  _MySqlTxDB(this._conn);

  @override
  Future<DbResult> rawQuery(
    String query, {
    Map<String, dynamic>? values,
  }) async {
    final result = await _conn.execute(query, values ?? {});
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
    return rawQuery(
      'INSERT INTO $table ($columns) VALUES ($placeholders);',
      values: data,
    );
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
    final conditions = where.keys.map((k) => '$k = :w_$k').join(' AND ');
    final whereParams = {for (final k in where.keys) 'w_$k': where[k]};
    return rawQuery(
      'UPDATE $table SET $sets WHERE $conditions;',
      values: {...data, ...whereParams},
    );
  }

  @override
  Future<DbResult> delete(
    String table, {
    required Map<String, dynamic> where,
  }) async {
    final conditions = where.keys.map((k) => '$k = :$k').join(' AND ');
    return rawQuery(
      'DELETE FROM $table WHERE $conditions;',
      values: where,
    );
  }
}
