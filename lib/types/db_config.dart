import 'db_type.dart';
import 'pool_config.dart';

class DbConfig {
  final DbType type;
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;

  /// Optional pool configuration. When null, drivers use [PoolConfig] defaults.
  final PoolConfig? poolConfig;

  const DbConfig({
    required this.type,
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    this.poolConfig,
  });
}
