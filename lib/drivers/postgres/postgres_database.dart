import 'package:postgres/postgres.dart';
import '../../core/dartapi_db_core.dart';
import '../../core/db_result.dart';
import '../../core/db_transaction.dart';
import '../../core/sql_database.dart';
import '../../core/sql_transaction.dart';
import '../../types/pool_config.dart';

/// A PostgreSQL implementation of [SqlDatabase] using a connection pool.
///
/// Overrides `insert`, `update`, and `delete` to append `RETURNING *` —
/// PostgreSQL can return the affected rows in a single round-trip. `select`
/// and the `ph`-based SQL building are inherited from [SqlDatabase].
class PostgresDatabase extends SqlDatabase {
  late final Pool _pool;

  PostgresDatabase(super.config);

  PoolConfig get _poolConfig => config.poolConfig ?? const PoolConfig();

  @override
  DbParamStyle get paramStyle => DbParamStyle.named;

  @override
  Future<void> connect() async {
    _pool = Pool.withEndpoints(
      [
        Endpoint(
          host: config.host,
          database: config.database,
          port: config.port,
          username: config.username,
          password: config.password,
        ),
      ],
      settings: PoolSettings(
        maxConnectionCount: _poolConfig.maxConnections,
        connectTimeout: _poolConfig.connectionTimeout,
        maxConnectionAge:
            _poolConfig.idleTimeout == Duration.zero
                ? null
                : _poolConfig.idleTimeout,
        sslMode: SslMode.disable,
      ),
    );
  }

  @override
  Future<void> close() async => _pool.close();

  @override
  Future<DbResult> rawQuery(
    String query, {
    Map<String, dynamic>? values,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      final result =
          values != null && values.isNotEmpty
              ? await _pool.execute(Sql.named(query), parameters: values)
              : await _pool.execute(Sql(query));
      final rows = result.map((row) => row.toColumnMap()).toList();
      return DbResult(
        rows: rows,
        affectedRows: rows.length,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      throw Exception('PostgreSQL query failed: $e');
    }
  }

  // PostgreSQL-specific overrides — append RETURNING * to get affected rows back.

  @override
  Future<DbResult> insert(String table, Map<String, dynamic> data) async {
    final columns = data.keys.join(', ');
    final placeholders = data.keys.map(ph).join(', ');
    return rawQuery(
      'INSERT INTO $table ($columns) VALUES ($placeholders) RETURNING *;',
      values: data,
    );
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
      'UPDATE $table SET $sets WHERE $conditions RETURNING *;',
      values: values,
    );
  }

  @override
  Future<DbResult> delete(
    String table, {
    required Map<String, dynamic> where,
  }) async {
    final conditions = where.keys.map((k) => '$k = ${ph(k)}').join(' AND ');
    return rawQuery(
      'DELETE FROM $table WHERE $conditions RETURNING *;',
      values: where,
    );
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
      'INSERT INTO $table ($colList) VALUES ${valueSets.join(', ')} RETURNING *;',
      values: params,
    );
  }

  @override
  Future<T> transaction<T>(Future<T> Function(DbTransaction tx) callback) =>
      _pool.runTx((session) => callback(_PostgresTxDB(session)));
}

/// Transaction-scoped DB backed by a PostgreSQL [TxSession].
///
/// Overrides `insert`, `update`, `delete` to append `RETURNING *`. `select`
/// is inherited from [SqlTransaction].
class _PostgresTxDB extends SqlTransaction {
  final TxSession _session;

  _PostgresTxDB(this._session);

  @override
  DbParamStyle get paramStyle => DbParamStyle.named;

  @override
  Future<DbResult> rawQuery(
    String query, {
    Map<String, dynamic>? values,
  }) async {
    final stopwatch = Stopwatch()..start();
    final result =
        values != null && values.isNotEmpty
            ? await _session.execute(Sql.named(query), parameters: values)
            : await _session.execute(Sql(query));
    final rows = result.map((row) => row.toColumnMap()).toList();
    return DbResult(
      rows: rows,
      affectedRows: rows.length,
      executionTime: stopwatch.elapsed,
    );
  }

  @override
  Future<DbResult> insert(String table, Map<String, dynamic> data) async {
    final columns = data.keys.join(', ');
    final placeholders = data.keys.map(ph).join(', ');
    return rawQuery(
      'INSERT INTO $table ($columns) VALUES ($placeholders) RETURNING *;',
      values: data,
    );
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
      'UPDATE $table SET $sets WHERE $conditions RETURNING *;',
      values: values,
    );
  }

  @override
  Future<DbResult> delete(
    String table, {
    required Map<String, dynamic> where,
  }) async {
    final conditions = where.keys.map((k) => '$k = ${ph(k)}').join(' AND ');
    return rawQuery(
      'DELETE FROM $table WHERE $conditions RETURNING *;',
      values: where,
    );
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
      'INSERT INTO $table ($colList) VALUES ${valueSets.join(', ')} RETURNING *;',
      values: params,
    );
  }
}
