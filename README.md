# dartapi_db

A lightweight database abstraction layer for DartAPI with support for PostgreSQL, MySQL, and SQLite. Provides a unified `DartApiDB` interface, connection pooling, transactions, and a SQL migration runner.

Part of the [DartAPI](https://pub.dev/packages/dartapi) ecosystem.

---

## Installation

```yaml
dependencies:
  dartapi_db: ^0.0.8
```

---

## Supported Drivers

| Driver | `DbType` | Notes |
|--------|----------|-------|
| PostgreSQL | `DbType.postgres` | Connection pool via `postgres` package |
| MySQL | `DbType.mysql` | Connection pool via `mysql_client_plus` |
| SQLite | `DbType.sqlite` | Embedded, no server required; supports `:memory:` |

---

## Getting Started

```dart
import 'package:dartapi_db/dartapi_db.dart';

// PostgreSQL
final db = await DatabaseFactory.create(DbConfig(
  type: DbType.postgres,
  host: 'localhost', port: 5432,
  database: 'mydb', username: 'postgres', password: 'secret',
  poolConfig: PoolConfig(maxConnections: 10),
));

// SQLite (no server needed)
final db = await DatabaseFactory.create(DbConfig.sqlite('app.db'));
// or in-memory:
final db = await DatabaseFactory.create(DbConfig.sqlite(':memory:'));
```

---

## CRUD Operations

```dart
// Insert
await db.insert('users', {'name': 'Alice', 'email': 'alice@example.com'});

// Select
final all = await db.select('users');
final one = await db.select('users', where: {'id': 1});

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

---

## Transactions

Wrap multiple operations in an atomic transaction. Automatically commits on success and rolls back on any exception.

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

Run pending migrations:

```dart
final runner = MigrationRunner(db);
await runner.migrate();
```

Or from the CLI (inside your DartAPI project):

```bash
dartapi generate migration create_users_table   # creates next numbered .sql file
dartapi db migrate                              # runs pending migrations
```

Applied migrations are tracked in a `_dartapi_migrations` table. Re-running is safe — already-applied files are skipped.

---

## Connection Pooling

```dart
const config = DbConfig(
  type: DbType.postgres,
  // ...
  poolConfig: PoolConfig(
    maxConnections: 20,
    minConnections: 2,
    connectionTimeout: Duration(seconds: 30),
    idleTimeout: Duration(minutes: 10),
  ),
);
```

---

## Links

- [dartapi CLI](https://pub.dev/packages/dartapi)
- [dartapi_core](https://pub.dev/packages/dartapi_core)
- [dartapi_auth](https://pub.dev/packages/dartapi_auth)
- [GitHub](https://github.com/akashgk/dartapi_db)
