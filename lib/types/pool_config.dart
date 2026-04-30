/// Configuration for the database connection pool.
///
/// Pass an instance to [DbConfig.poolConfig] to enable pooling with
/// custom settings. All fields have sensible defaults.
class PoolConfig {
  /// Maximum number of simultaneously open connections.
  final int maxConnections;

  /// Minimum connections to keep alive (MySQL only; Postgres manages its own lifecycle).
  final int minConnections;

  /// How long to wait for a free connection before throwing [TimeoutException].
  final Duration connectionTimeout;

  /// How long an idle connection is kept before being closed (MySQL only).
  /// Set to [Duration.zero] to disable idle eviction.
  final Duration idleTimeout;

  const PoolConfig({
    this.maxConnections = 10,
    this.minConnections = 2,
    this.connectionTimeout = const Duration(seconds: 30),
    this.idleTimeout = const Duration(minutes: 10),
  }) : assert(
         minConnections <= maxConnections,
         'minConnections must be <= maxConnections',
       );
}
