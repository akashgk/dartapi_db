import 'db_result.dart';

abstract class DartApiDB {
  Future<void> connect();
  Future<void> close();

  Future<DbResult> rawQuery(String query, {Map<String, dynamic>? values});

  Future<DbResult> insert(String table, Map<String, dynamic> data);
  Future<DbResult> select(String table, {Map<String, dynamic>? where});
  Future<DbResult> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> where,
  });
  Future<DbResult> delete(String table, {required Map<String, dynamic> where});
}
