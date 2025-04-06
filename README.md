# DartAPI DB

DartAPI DB is a lightweight and flexible database abstraction package for Dart that provides structured SQL database support using a unified API interface. It is designed to support multiple database drivers (currently PostgreSQL and MySQL) while maintaining clean architecture and SOLID principles.

## ✨ Features

- ✅ Common interface for all SQL databases
- ✅ Easily extendable to support more databases
- ✅ Clean structure following SOLID principles
- ✅ Lightweight and fast
- ✅ No ORM overhead

## 📦 Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  dartapi_db: ^0.0.1
```

## 🔧 Supported Drivers

- PostgreSQL (`postgres`)
- MySQL (`mysql_client_plus`)

## 🚀 Getting Started

### Example usage:

```dart
import 'package:dartapi_db/dartapi_db.dart';

void main() async {
  final db = await DatabaseFactory.create(
    DbConfig(
      type: DbType.postgres,
      host: 'localhost',
      port: 5432,
      database: 'mydb',
      username: 'postgres',
      password: 'password',
    ),
  );

  final result = await db.select('users', where: {'id': 1});
  print(result.first);
}
```

## 🧪 Testing

To run the tests:

```bash
dart test
```

## 📁 Structure

- `core/`: Base interface and result classes
- `drivers/`: Implementations for PostgreSQL and MySQL
- `types/`: Configuration and enums
- `factory/`: Driver resolver

## 📄 License
This package is open-source and licensed under the **BSD-3-Clause License**.
