import 'db_result.dart';

/// The core interface for database access in DartAPI.
///
/// This abstract class defines a common API for SQL database interactions,
/// such as querying, inserting, updating, and deleting data. Concrete implementations
/// (e.g., for PostgreSQL or MySQL) must implement these methods.
///
/// The interface is designed to be simple and flexible, allowing developers to
/// write database-agnostic code.
abstract class DartApiDB {
  /// Establishes a connection to the database.
  ///
  /// This should be called before executing any queries.
  Future<void> connect();

  /// Closes the database connection.
  Future<void> close();

  /// Executes a raw SQL query and returns the result.
  ///
  /// - [query]: The SQL query to execute.
  /// - [values]: Optional named parameters for substitution (e.g., `@name`).
  Future<DbResult> rawQuery(String query, {Map<String, dynamic>? values});

  /// Inserts a new row into the specified [table].
  ///
  /// - [data]: A map of column names and values.
  /// Returns the inserted row(s) if supported.
  Future<DbResult> insert(String table, Map<String, dynamic> data);

  /// Retrieves data from the specified [table].
  ///
  /// - [where]: Optional filter conditions (e.g., `{'id': 1}`).
  Future<DbResult> select(String table, {Map<String, dynamic>? where});

  /// Updates one or more rows in the specified [table].
  ///
  /// - [data]: Column values to update.
  /// - [where]: Conditions to match rows (e.g., `{'id': 1}`).
  Future<DbResult> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> where,
  });

  /// Deletes one or more rows from the specified [table].
  ///
  /// - [where]: Conditions to match rows (e.g., `{'id': 1}`).
  Future<DbResult> delete(String table, {required Map<String, dynamic> where});
}
