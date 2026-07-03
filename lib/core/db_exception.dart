/// Typed exceptions thrown by every `dartapi_db` driver.
///
/// All database errors surface as a [DbException] subclass, so application
/// code can map them to HTTP responses without parsing driver messages:
///
/// ```dart
/// try {
///   await db.insert('users', {'email': dto.email, ...});
/// } on UniqueViolationException {
///   throw const ApiException(409, 'Email already registered');
/// } on DbConnectionException {
///   throw const ApiException(503, 'Database unavailable');
/// }
/// ```
///
/// The original driver exception is preserved in [cause] for logging and
/// debugging.
class DbException implements Exception {
  /// Human-readable description of what failed.
  final String message;

  /// The underlying driver exception, when available.
  final Object? cause;

  const DbException(this.message, {this.cause});

  @override
  String toString() =>
      '$runtimeType: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// A UNIQUE (or PRIMARY KEY) constraint was violated — e.g. inserting a
/// duplicate email. Typically mapped to HTTP `409 Conflict`.
class UniqueViolationException extends DbException {
  const UniqueViolationException(super.message, {super.cause});
}

/// A FOREIGN KEY constraint was violated — referencing a missing row, or
/// deleting a row that is still referenced. Typically mapped to HTTP
/// `409 Conflict` or `422`.
class ForeignKeyViolationException extends DbException {
  const ForeignKeyViolationException(super.message, {super.cause});
}

/// The database could not be reached (connection refused, dropped, TLS
/// failure, timeout). Typically mapped to HTTP `503 Service Unavailable`.
class DbConnectionException extends DbException {
  const DbConnectionException(super.message, {super.cause});
}

/// Any other failed statement — SQL syntax errors, unknown columns,
/// type mismatches, etc.
class QueryException extends DbException {
  const QueryException(super.message, {super.cause});
}
