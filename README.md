# dartapi_db

A lightweight database abstraction layer for the [DartAPI](https://pub.dev/packages/dartapi) ecosystem. Provides a unified `DartApiDB` interface over PostgreSQL, MySQL, and SQLite with connection pooling, transactions, and a SQL migration runner.

---

## Installation

```yaml
dependencies:
  dartapi_db: ^0.2.0
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

The one-liner — pass your platform's `DATABASE_URL` straight through
(TLS via `?sslmode=require`, as required by Neon/Supabase/RDS/etc.):

```dart
import 'package:dartapi_db/dartapi_db.dart';

final db = await DatabaseFactory.fromUrl(Platform.environment['DATABASE_URL']!);
// postgres://user:pass@host:5432/mydb?sslmode=require
// mysql://root:secret@localhost/mydb
// sqlite:app.db          sqlite::memory:
```

Or configure explicitly:

```dart
// PostgreSQL
final db = await DatabaseFactory.create(DbConfig(
  type: DbType.postgres,
  host: 'localhost',
  port: 5432,
  database: 'mydb',
  username: 'postgres',
  password: 'secret',
  useSsl: true,                             // managed/cloud databases
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

## Error Handling

Every driver error surfaces as a typed `DbException` subclass — map them to
HTTP statuses without parsing strings:

| Exception | Meaning | Typical HTTP status |
|---|---|---|
| `UniqueViolationException` | duplicate key (e.g. email taken) | 409 |
| `ForeignKeyViolationException` | missing/still-referenced row | 409 / 422 |
| `DbConnectionException` | database unreachable | 503 |
| `QueryException` | any other failed statement | 500 |

```dart
try {
  await db.insert('users', {'email': dto.email, 'name': dto.name});
} on UniqueViolationException {
  throw const ApiException(409, 'Email already registered');
}
```

The original driver exception is preserved in `.cause` for logging.

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

## Query Builder & Pagination

```dart
// Fluent filtering and sorting
final admins = await db.query('users')
    .where('role', equals: 'admin')
    .where('age', greaterThan: 18)
    .orderBy('name')
    .get();

// One call → one page of rows + the total count, all in SQL
final page = await db.query('users')
    .where('active', equals: true)
    .orderBy('id')
    .paginate(page: 2, limit: 20);
// page.rows, page.total, page.totalPages, page.hasNext, page.hasPrev

// Plugs straight into dartapi_core's PaginatedResponse:
return PaginatedResponse(
  data: page.map(User.fromRow),
  pagination: Pagination(page: page.page, limit: page.limit),
  total: page.total,
);

// Existence checks and counts
final taken = await db.query('users').where('email', equals: email).exists();
final total = await db.query('users').count();
```

---

## Transactions

Wrap multiple operations in an atomic transaction. The callback commits on success and rolls back automatically on any exception. The query builder works inside transactions too (`tx.query(...)`).

```dart
final orderId = await db.transaction((tx) async {
  final order = await tx.insert('orders', {'total': 99.99});
  await tx.insert('order_items', {
    'order_id': order.first!['id'],
    'sku': 'ABC-001',
  });
  final items = await tx.query('order_items')
      .where('order_id', equals: order.first!['id'])
      .count();
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
