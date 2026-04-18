import 'package:postgres/postgres.dart';
import '../../core/sql_database.dart';
import '../../core/db_result.dart';
import '../../core/db_transaction.dart';
import '../../types/pool_config.dart';

/// A PostgreSQL implementation of [SqlDatabase] using a connection pool.
///
/// Uses the `postgres` package's [Pool] to manage multiple concurrent
/// connections, eliminating single-connection bottlenecks under load.
class PostgresDatabase extends SqlDatabase {
  late final Pool _pool;

  PostgresDatabase(super.config);

  PoolConfig get _poolConfig => config.poolConfig ?? const PoolConfig();

  /// Opens the connection pool to the PostgreSQL database.
  ///
  /// The pool is lazy — physical connections are opened on first use.
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
        maxConnectionAge: _poolConfig.idleTimeout == Duration.zero
            ? null
            : _poolConfig.idleTimeout,
        sslMode: SslMode.disable,
      ),
    );
  }

  /// Closes all connections in the pool.
  @override
  Future<void> close() async => _pool.close();

  /// Executes a raw SQL query with optional named parameters.
  ///
  /// Acquires a session from the pool for the duration of the query.
  /// If [values] is non-empty, the query is parsed using [Sql.named].
  @override
  Future<DbResult> rawQuery(
    String query, {
    Map<String, dynamic>? values,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();

      final result = values != null && values.isNotEmpty
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

  /// Inserts a new row into the specified [table] and returns the inserted data.
  ///
  /// Uses `RETURNING *` to fetch and return the inserted row(s).
  @override
  Future<DbResult> insert(String table, Map<String, dynamic> data) async {
    final columns = data.keys.join(', ');
    final values = data.keys.map((k) => '@$k').join(', ');
    final query = 'INSERT INTO $table ($columns) VALUES ($values) RETURNING *;';
    return rawQuery(query, values: data);
  }

  /// Updates matching rows in the [table] with the given [data].
  ///
  /// All keys in [where] are prefixed with `w_` to avoid naming collisions.
  /// Returns the updated row(s).
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

  /// Deletes rows from the specified [table] based on the [where] clause.
  ///
  /// Returns the deleted row(s).
  @override
  Future<DbResult> delete(
    String table, {
    required Map<String, dynamic> where,
  }) async {
    final conditions = where.keys.map((k) => '$k = @$k').join(' AND ');
    final query = 'DELETE FROM $table WHERE $conditions RETURNING *;';
    return rawQuery(query, values: where);
  }

  /// Runs [callback] inside a PostgreSQL transaction using [Pool.runTx].
  ///
  /// Automatically commits on success and rolls back on any exception.
  @override
  Future<T> transaction<T>(Future<T> Function(DbTransaction tx) callback) =>
      _pool.runTx((session) => callback(_PostgresTxDB(session)));
}

/// A [DbTransaction] implementation backed by a PostgreSQL [TxSession].
class _PostgresTxDB implements DbTransaction {
  final TxSession _session;

  _PostgresTxDB(this._session);

  @override
  Future<DbResult> rawQuery(
    String query, {
    Map<String, dynamic>? values,
  }) async {
    final stopwatch = Stopwatch()..start();
    final result = values != null && values.isNotEmpty
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
    final placeholders = data.keys.map((k) => '@$k').join(', ');
    return rawQuery(
      'INSERT INTO $table ($columns) VALUES ($placeholders) RETURNING *;',
      values: data,
    );
  }

  @override
  Future<DbResult> select(String table, {Map<String, dynamic>? where}) async {
    var query = 'SELECT * FROM $table';
    final params = <String, dynamic>{};
    if (where != null && where.isNotEmpty) {
      final conditions = where.keys.map((k) => '$k = @$k').join(' AND ');
      query += ' WHERE $conditions';
      params.addAll(where);
    }
    return rawQuery(query, values: params);
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
    final conditions = where.keys.map((k) => '$k = @$k').join(' AND ');
    return rawQuery(
      'DELETE FROM $table WHERE $conditions RETURNING *;',
      values: where,
    );
  }
}
