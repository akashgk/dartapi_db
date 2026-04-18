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
