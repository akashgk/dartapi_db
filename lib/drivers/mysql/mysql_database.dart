import 'package:mysql_client_plus/mysql_client_plus.dart';
import '../../types/pool_config.dart';
import '../../core/dartapi_db_core.dart';
import '../../core/db_result.dart';
import '../../core/db_transaction.dart';
import '../../core/sql_database.dart';
import '../../core/sql_transaction.dart';

/// A MySQL implementation of [SqlDatabase] using a connection pool.
///
/// Extends [SqlDatabase] so `insert`, `select`, `update`, and `delete` are
/// inherited — only [rawQuery] and [transaction] are MySQL-specific.
///
/// Uses [MySQLConnectionPool] from `mysql_client_plus`. [PoolConfig.minConnections]
/// and [PoolConfig.idleTimeout] are not supported by the underlying pool and are
/// silently ignored.
class MySqlDatabase extends SqlDatabase {
  late final MySQLConnectionPool _pool;

  MySqlDatabase(super.config);

  PoolConfig get _poolConfig => config.poolConfig ?? const PoolConfig();

  @override
  DbParamStyle get paramStyle => DbParamStyle.colon;

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

  @override
  Future<void> close() async => _pool.close();

  @override
  Future<DbResult> rawQuery(
    String query, {
    Map<String, dynamic>? values,
  }) async {
    final stopwatch = Stopwatch()..start();
    final result = await _pool.execute(query, values ?? {});
    return DbResult(
      rows: result.rows.map((row) => row.assoc()).toList(),
      affectedRows: result.affectedRows.toInt(),
      insertId: result.lastInsertID,
      executionTime: stopwatch.elapsed,
    );
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(DbTransaction tx) callback,
  ) async {
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

/// Transaction-scoped DB backed by a single [MySQLConnection].
///
/// SQL building is inherited from [SqlTransaction] with colon-style params.
class _MySqlTxDB extends SqlTransaction {
  final MySQLConnection _conn;

  _MySqlTxDB(this._conn);

  @override
  DbParamStyle get paramStyle => DbParamStyle.colon;

  @override
  Future<DbResult> rawQuery(
    String query, {
    Map<String, dynamic>? values,
  }) async {
    final stopwatch = Stopwatch()..start();
    final result = await _conn.execute(query, values ?? {});
    return DbResult(
      rows: result.rows.map((row) => row.assoc()).toList(),
      affectedRows: result.affectedRows.toInt(),
      insertId: result.lastInsertID,
      executionTime: stopwatch.elapsed,
    );
  }
}
