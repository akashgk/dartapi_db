import 'dart:io';

import '../core/dartapi_db_core.dart';

/// A lightweight SQL migration runner.
///
/// Scans a directory for `*.sql` migration files (sorted alphabetically),
/// tracks which ones have been applied in a `_dartapi_migrations` table,
/// and applies any pending migrations in order.
///
/// **Convention:** name files with a numeric prefix so they sort correctly:
/// ```
/// migrations/
/// ├── 0001_create_users.sql
/// ├── 0002_add_email_index.sql
/// └── 0003_create_products.sql
/// ```
///
/// **Usage:**
/// ```dart
/// final runner = MigrationRunner(db);
/// await runner.migrate();
/// ```
///
/// Call `dartapi db migrate` from the CLI instead of calling this directly
/// when running from the project root.
class MigrationRunner {
  final DartApiDB db;

  /// Path to the directory containing `.sql` migration files.
  final String migrationsPath;

  MigrationRunner(this.db, {this.migrationsPath = 'migrations'});

  /// Applies all pending migrations.
  ///
  /// Creates the `_dartapi_migrations` tracking table if it does not exist.
  /// Runs each unapplied `.sql` file inside a transaction and records it.
  ///
  /// When [dryRun] is `true`, pending migrations are printed but not applied —
  /// useful for CI checks or previewing what `migrate()` would do:
  ///
  /// ```dart
  /// await runner.migrate(dryRun: true);
  /// // → [DRY RUN] Would apply: 0003_add_index.sql
  /// ```
  Future<void> migrate({bool dryRun = false}) async {
    if (!dryRun) await _ensureMigrationsTable();

    final applied = dryRun ? <String>{} : await _appliedMigrations();
    final pending = await _pendingMigrations(applied);

    if (pending.isEmpty) {
      print(dryRun
          ? '[DRY RUN] No pending migrations.'
          : '✅ No pending migrations.');
      return;
    }

    if (dryRun) {
      print('[DRY RUN] ${pending.length} pending migration(s):');
      for (final file in pending) {
        print('  • ${_fileName(file)}');
      }
      return;
    }

    for (final file in pending) {
      final name = _fileName(file);
      print('⏳ Applying migration: $name');

      final sql = file.readAsStringSync();

      await db.transaction((tx) async {
        await tx.rawQuery(sql);
        await tx.rawQuery(
          'INSERT INTO _dartapi_migrations (name) VALUES (:name);',
          values: {'name': name},
        );
      });

      print('✅ Applied: $name');
    }

    print('🎉 All migrations applied (${pending.length} total).');
  }

  /// Returns the list of migration names that have already been applied.
  Future<Set<String>> appliedMigrations() => _appliedMigrations();

  Future<void> _ensureMigrationsTable() async {
    await db.rawQuery('''
      CREATE TABLE IF NOT EXISTS _dartapi_migrations (
        name       VARCHAR(255) PRIMARY KEY,
        applied_at TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
      );
    ''');
  }

  Future<Set<String>> _appliedMigrations() async {
    final result = await db.rawQuery(
      'SELECT name FROM _dartapi_migrations ORDER BY name;',
    );
    return result.rows.map((r) => r['name'] as String).toSet();
  }

  Future<List<File>> _pendingMigrations(Set<String> applied) async {
    final dir = Directory(migrationsPath);
    if (!dir.existsSync()) {
      throw StateError(
        'Migrations directory "$migrationsPath" does not exist. '
        'Create it and add .sql files.',
      );
    }

    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.sql'))
            .toList()
          ..sort((a, b) => _fileName(a).compareTo(_fileName(b)));

    return files.where((f) => !applied.contains(_fileName(f))).toList();
  }

  String _fileName(File file) => file.uri.pathSegments.last;
}
