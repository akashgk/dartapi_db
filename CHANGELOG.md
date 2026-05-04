## 0.0.15

**New features.**

- Add `DbResult.map<T>(mapper)` — maps every row to `T` using a mapper function, returning `List<T>`.
- Add `DbResult.firstAs<T>(mapper)` — maps the first row to `T`, or returns `null` if the result is empty.
- Add `DartApiDB.insertBatch(table, rows)` and `DbTransaction.insertBatch(table, rows)` — inserts multiple rows in a single `INSERT ... VALUES (...), (...)` statement. PostgreSQL returns inserted rows via `RETURNING *`; MySQL and SQLite set `affectedRows`. Empty list is a no-op.
- Add identifier quoting to `QueryBuilder` — table names and column names are now quoted correctly for each driver (`"identifier"` for PostgreSQL/SQLite, `` `identifier` `` for MySQL), preventing conflicts with reserved keywords.
- Add runtime warning when `whereIn` list exceeds 1 000 items — large `IN` clauses degrade performance; the warning suggests using a JOIN or temporary table instead.
- Add `dryRun` parameter to `MigrationRunner.migrate()` — prints pending migrations without applying them. Useful for CI checks and deploy previews.

## 0.0.14

**Bug fixes.**

- Fix `MySqlDatabase.rawQuery` and `_MySqlTxDB.rawQuery` — `DbResult.executionTime` is now populated for MySQL queries and transactions, consistent with PostgreSQL and SQLite.
- Fix `SqliteDatabase.update` and `_SqliteTxDB.update` — WHERE-clause values are now stored under prefixed keys (`w_<col>`) in the positional params map, matching the PostgreSQL driver. Previously, when a column appeared in both `data` and `where` (e.g. updating `name` WHERE `name = old`), the map collapsed to a single entry and the second positional `?` was bound incorrectly, causing silent data corruption.
- Fix `QueryBuilder.where(whereIn:)` — throws `ArgumentError` immediately when an empty list is passed instead of silently generating invalid SQL `IN ()` that fails at the database level.
- Dependency upgrades: `test` 1.31.0 → 1.31.1, `test_api` 0.7.11 → 0.7.12, `test_core` 0.6.17 → 0.6.18, `matcher` 0.12.19 → 0.12.20, `analyzer` 12.1.0 → 13.0.0, `vm_service` 15.1.0 → 15.2.0.

## 0.0.13

**Milestone 4 — MySQL `SqlDatabase` Consistency.**

- `MySqlDatabase` now `extends SqlDatabase` instead of `implements DartApiDB` — `insert`, `select`, `update`, and `delete` are inherited; only `rawQuery`, `transaction`, `connect`, `close`, and `paramStyle` are MySQL-specific.
- Add `SqlTransaction` abstract class (`lib/core/sql_transaction.dart`) — mirrors `SqlDatabase` for transaction-scoped operations. `_MySqlTxDB` and `_PostgresTxDB` both extend it, eliminating duplicated SQL-building in transaction callbacks.
- Add `ph(String key)` method to `SqlDatabase` and `SqlTransaction` — returns `:key` for colon style (MySQL) or `@key` for named style (PostgreSQL), so all CRUD methods emit the correct placeholder automatically.
- `PostgresDatabase` is updated to use `ph()` in its `RETURNING *` overrides; `_PostgresTxDB` inherits `select` from `SqlTransaction` (no longer duplicated).
- No SQL-building logic is duplicated across drivers or transaction classes.
- Add `test/mysql_consistency_test.dart` — 17 unit tests verifying MySQL inherits correct `:param` SQL from `SqlDatabase` via a stub that captures generated SQL without a live server.
- Full suite: **78 tests passing**.

## 0.0.12
- Upgrade `sqlite3` from `^2.4.0` to `^3.3.1` — fixes deprecation warning (`dispose()` → `close()`)
- Upgrade `mysql_client_plus` from `^0.0.31` to `^0.1.2`
- Upgrade `lints` from `^5.0.0` to `^6.1.0`

## 0.0.11
- Add `QueryBuilder` — fluent SELECT query builder returned by `db.query(table)`
  - `.where(column, {equals, notEquals, greaterThan, lessThan, greaterThanOrEqual, lessThanOrEqual, like, whereIn, isNull, isNotNull})` — rich WHERE conditions (all AND-joined)
  - `.select(columns)` — restrict to specific columns instead of `SELECT *`
  - `.orderBy(column, {ascending})` — multi-column sorting
  - `.limit(n)` / `.offset(n)` — offset-based pagination; SQLite emits `LIMIT -1 OFFSET n` automatically
  - `.get()` → `Future<DbResult>` — all matching rows
  - `.first()` → `Future<Map<String,dynamic>?>` — first row or null
  - `.count()` → `Future<int>` — row count (ignores ORDER BY / LIMIT / OFFSET)
- Add `DbParamStyle` enum (`named` / `colon` / `positional`) and `DartApiDB.paramStyle` getter — drivers declare their placeholder style; `QueryBuilder` generates correct SQL automatically for all three drivers
- Add `DbQueryExtension` on `DartApiDB` — provides `db.query(table)` without circular imports

## 0.0.10
- Add `test/mysql_query_builder_test.dart` — regression tests for Bug 1 (MySQL `update()` SET/WHERE parameter collision); validates that `w_` prefix correctly isolates WHERE params from SET params

## 0.0.9
- Improve README: add MySQL connection example, improve clarity

## 0.0.8
- Add `DbTransaction` abstract class for transaction-scoped query sessions
- Add `DartApiDB.transaction<T>(callback)` — runs callback in a DB transaction; commits on success, rolls back on exception
  - PostgreSQL: uses `Pool.runTx()` (native transaction session)
  - MySQL: acquires a dedicated connection via `pool.withConnection()` with `START TRANSACTION` / `COMMIT` / `ROLLBACK`
  - SQLite: uses `BEGIN` / `COMMIT` / `ROLLBACK` on the same connection
- Add `SqliteDatabase` driver — full `DartApiDB` implementation backed by `sqlite3`
- Add `DbType.sqlite` enum value
- Add `DbConfig.sqlite(String path)` convenience constructor; use `':memory:'` for in-memory databases
- Add `MigrationRunner` — Flyway-style SQL migration runner that tracks applied migrations in `_dartapi_migrations`
- Add 19 tests for SQLite and MigrationRunner (no server required)

## 0.0.7
- Add connection pooling for PostgreSQL (via `Pool.withEndpoints`) and MySQL (via `MySQLConnectionPool`)
- Add `PoolConfig` class with `maxConnections`, `minConnections`, `connectionTimeout`, and `idleTimeout`
- Add optional `poolConfig` field to `DbConfig` — backward compatible, defaults to `PoolConfig()` when omitted

## 0.0.6
- Fix `MySqlDatabase.update()` parameter collision when the same column appears in both SET and WHERE clauses (WHERE params now use `w_` prefix internally)

## 0.0.5
- Upgrade Postgres to ^3.5.6 from ^2.6.2

## 0.0.4
- Upgrade Postgres to ^3.5.6 from ^2.6.2

## 0.0.3
- Add Code Doc

## 0.0.2
- Fix Test and Exports.

## 0.0.1
- Initial version.
