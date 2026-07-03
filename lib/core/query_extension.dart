import 'dartapi_db_core.dart';
import '../query/query_builder.dart';

/// Adds [query] to every [QueryExecutor] — both [DartApiDB] connections
/// and [DbTransaction] sessions inside `db.transaction(...)`.
extension DbQueryExtension on QueryExecutor {
  /// Returns a [QueryBuilder] targeting [table].
  ///
  /// ```dart
  /// // All rows where age > 18, sorted by name, page 2
  /// final result = await db.query('users')
  ///     .where('age', greaterThan: 18)
  ///     .orderBy('name')
  ///     .limit(20)
  ///     .offset(20)
  ///     .get();
  ///
  /// // Single row lookup
  /// final user = await db.query('users').where('id', equals: id).first();
  ///
  /// // Count with filter
  /// final adminCount = await db.query('users')
  ///     .where('role', equals: 'admin')
  ///     .count();
  /// ```
  QueryBuilder query(String table) => QueryBuilder(this, table);
}
