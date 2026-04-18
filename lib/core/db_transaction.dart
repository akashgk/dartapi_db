import 'db_result.dart';

/// A database transaction session.
///
/// Provides the same query methods as [DartApiDB] without the lifecycle
/// methods (`connect`, `close`). Passed to the callback in
/// [DartApiDB.transaction].
///
/// ```dart
/// await db.transaction((tx) async {
///   await tx.insert('orders', orderData);
///   await tx.insert('order_items', itemData);
/// });
/// ```
abstract class DbTransaction {
  Future<DbResult> rawQuery(String query, {Map<String, dynamic>? values});

  Future<DbResult> insert(String table, Map<String, dynamic> data);

  Future<DbResult> select(String table, {Map<String, dynamic>? where});

  Future<DbResult> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> where,
  });

  Future<DbResult> delete(
    String table, {
    required Map<String, dynamic> where,
  });
}
