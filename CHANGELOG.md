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
