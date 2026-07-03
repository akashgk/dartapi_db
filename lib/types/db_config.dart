import 'db_type.dart';
import 'pool_config.dart';

class DbConfig {
  final DbType type;
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;

  /// Whether to connect over TLS.
  ///
  /// Required by most managed databases (Neon, Supabase, RDS, PlanetScale).
  /// Defaults to `false` for local development.
  final bool useSsl;

  /// Optional pool configuration. When null, drivers use [PoolConfig] defaults.
  final PoolConfig? poolConfig;

  const DbConfig({
    required this.type,
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    this.useSsl = false,
    this.poolConfig,
  });

  /// Convenience constructor for SQLite databases.
  ///
  /// [databasePath] is the file path to the SQLite database (e.g. `'app.db'`).
  /// Use `':memory:'` for an in-memory database.
  const DbConfig.sqlite(String databasePath)
    : type = DbType.sqlite,
      host = '',
      port = 0,
      database = databasePath,
      username = '',
      password = '',
      useSsl = false,
      poolConfig = null;

  /// Parses a 12-factor style database URL — the format every PaaS hands
  /// you as `DATABASE_URL`:
  ///
  /// ```dart
  /// DbConfig.fromUrl('postgres://user:pass@db.example.com:5432/mydb?sslmode=require')
  /// DbConfig.fromUrl('mysql://root:secret@localhost/mydb')
  /// DbConfig.fromUrl('sqlite:app.db')          // relative file
  /// DbConfig.fromUrl('sqlite::memory:')        // in-memory
  /// ```
  ///
  /// Supported schemes: `postgres`/`postgresql`, `mysql`, `sqlite`.
  /// TLS is enabled by `?sslmode=require|verify-ca|verify-full` or
  /// `?ssl=true` (default ports: 5432/3306).
  ///
  /// Throws [FormatException] for unknown schemes or missing parts.
  factory DbConfig.fromUrl(String url, {PoolConfig? poolConfig}) {
    if (url.startsWith('sqlite:')) {
      final path = url.substring('sqlite:'.length).replaceFirst('//', '');
      if (path.isEmpty) {
        throw const FormatException('sqlite: URL is missing a database path');
      }
      return DbConfig.sqlite(path);
    }

    final uri = Uri.parse(url);
    final type = switch (uri.scheme) {
      'postgres' || 'postgresql' => DbType.postgres,
      'mysql' => DbType.mysql,
      _ =>
        throw FormatException(
          'Unsupported database URL scheme "${uri.scheme}" — expected '
          'postgres://, postgresql://, mysql://, or sqlite:',
        ),
    };

    final database =
        uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    if (uri.host.isEmpty || database.isEmpty) {
      throw FormatException(
        'Database URL must include a host and a database name: $url',
      );
    }

    final userInfo = uri.userInfo.split(':');
    final sslMode = uri.queryParameters['sslmode'];
    final useSsl =
        (sslMode != null && sslMode != 'disable') ||
        uri.queryParameters['ssl'] == 'true';

    return DbConfig(
      type: type,
      host: uri.host,
      port: uri.hasPort ? uri.port : (type == DbType.postgres ? 5432 : 3306),
      database: database,
      username: userInfo.isNotEmpty ? Uri.decodeComponent(userInfo[0]) : '',
      password: userInfo.length > 1 ? Uri.decodeComponent(userInfo[1]) : '',
      useSsl: useSsl,
      poolConfig: poolConfig,
    );
  }
}
