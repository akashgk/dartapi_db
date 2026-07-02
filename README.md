# dartapi_db

A lightweight database abstraction layer for the [DartAPI](https://pub.dev/packages/dartapi) ecosystem. Provides a unified `DartApiDB` interface over PostgreSQL, MySQL, and SQLite with connection pooling, transactions, and a SQL migration runner.

---

## Installation

```yaml
dependencies:
  dartapi_db: ^0.1.0
```

---

## Supported Drivers

| Driver | `DbType` | Notes |
|--------|----------|-------|
| PostgreSQL | `DbType.postgres` | Connection pool via `postgres` package |
| MySQL | `DbType.mysql` | Connection pool via `mysql_client_plus` |
| SQLite | `DbType.sqlite` | Embedded, no server required; supports `:memory:` |

---

## Connecting

```dart
import 'package:dartapi_db/dartapi_db.dart';

// PostgreSQL
final db = await DatabaseFactory.create(DbConfig(
  type: DbType.postgres,
  host: 'localhost',
  port: 5432,
  database: 'mydb',
  username: 'postgres',
  password: 'secret',
  poolConfig: PoolConfig(maxConnections: 10),
));

// MySQL
final db = await DatabaseFactory.create(DbConfig(
  type: DbType.mysql,
  host: 'localhost',
  port: 3306,
  database: 'mydb',
  username: 'root',
  password: 'secret',
));

// SQLite
final db = await DatabaseFactory.create(DbConfig.sqlite('app.db'));

// SQLite in-memory (useful for tests)
final db = await DatabaseFactory.create(DbConfig.sqlite(':memory:'));
```

---

## CRUD Operations

```dart
// Insert
await db.insert('users', {'name': 'Alice', 'email': 'alice@example.com'});

// Select all
final rows = await db.select('users');

// Select with filter
final row = await db.select('users', where: {'id': 1});

// Update
await db.update('users', {'name': 'Alicia'}, where: {'id': 1});

// Delete
await db.delete('users', where: {'id': 1});

// Raw SQL
final result = await db.rawQuery(
  'SELECT * FROM users WHERE age > @min',
  values: {'min': 18},
);
```

`DbResult` exposes `.rows`, `.affectedRows`, `.insertId`, and `.executionTime`.

---

## Transactions

Wrap multiple operations in an atomic transaction. The callback commits on success and rolls back automatically on any exception.

```dart
final orderId = await db.transaction((tx) async {
  final order = await tx.insert('orders', {'total': 99.99});
  await tx.insert('order_items', {
    'order_id': order.first!['id'],
    'sku': 'ABC-001',
  });
  return order.first!['id'];
});
```

---

## Migrations

Place numbered `.sql` files in a `migrations/` directory:

```
migrations/
├── 0001_create_users.sql
├── 0002_add_email_index.sql
└── 0003_create_products.sql
```

Run pending migrations programmatically:

```dart
final runner = MigrationRunner(db);
await runner.migrate();
```

Or from the CLI inside a DartAPI project:

```bash
# Create the next numbered migration file
dartapi generate migration create_orders_table

# Apply all pending migrations
dartapi db migrate
```

Applied migrations are tracked in a `_dartapi_migrations` table. Re-running is safe — already-applied files are skipped.

---

## Connection Pooling

Configure pool behaviour via `PoolConfig` (PostgreSQL and MySQL):

```dart
const config = DbConfig(
  type: DbType.postgres,
  host: 'localhost',
  port: 5432,
  database: 'mydb',
  username: 'postgres',
  password: 'secret',
  poolConfig: PoolConfig(
    maxConnections: 20,
    minConnections: 2,
    connectionTimeout: Duration(seconds: 30),
    idleTimeout: Duration(minutes: 10),
  ),
);
```

---

## Health Checks

`db.ping()` answers `true` when the database responds to `SELECT 1` within
the timeout (default 2 s) and `false` otherwise — it never throws, so it is
safe to call from a health endpoint:

```dart
app.enableHealthCheck(checks: [
  () async => HealthCheckResult(name: 'database', healthy: await db.ping()),
]);
```

---

## Running the Tests

```bash
dart test                    # unit tests only — no database needed
docker compose up -d         # start Postgres + MySQL
dart test -P integration     # integration tests against live databases
```

---

## Links

- [dartapi CLI](https://pub.dev/packages/dartapi)
- [dartapi_core](https://pub.dev/packages/dartapi_core)
- [GitHub](https://github.com/akashgk/dartapi_db)

---

## License

BSD 3-Clause License © 2025 Akash G Krishnan
