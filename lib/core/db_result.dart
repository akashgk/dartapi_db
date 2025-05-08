/// Represents the result of a database operation.
///
/// Contains the rows returned by the query, metadata such as affected rows,
/// optional insert ID, and execution time for performance tracking.
class DbResult {
  /// The list of rows returned by the query.
  ///
  /// Each row is represented as a `Map<String, dynamic>`.
  final List<Map<String, dynamic>> rows;

  /// The number of rows affected by the operation.
  ///
  /// Typically used with `UPDATE`, `INSERT`, or `DELETE` queries.
  final int? affectedRows;

  /// The ID of the newly inserted row, if applicable.
  ///
  /// Only returned for databases and queries that support it (e.g., PostgreSQL `RETURNING`).
  final dynamic insertId;

  /// The duration it took to execute the query.
  final Duration? executionTime;

  /// Creates a new [DbResult].
  const DbResult({
    required this.rows,
    this.affectedRows,
    this.insertId,
    this.executionTime,
  });

  /// Returns the first row in the result set, or `null` if empty.
  Map<String, dynamic>? get first => rows.isEmpty ? null : rows.first;

  /// Returns `true` if the result set contains no rows.
  bool get isEmpty => rows.isEmpty;

  /// Returns `true` if the result set is not empty.
  bool get isNotEmpty => rows.isNotEmpty;
}
