/// One page of query results plus the pagination metadata computed by
/// `QueryBuilder.paginate`.
///
/// Plugs directly into `dartapi_core`'s `PaginatedResponse`:
///
/// ```dart
/// final page = await db.query('users').orderBy('id').paginate(page: 2);
/// return PaginatedResponse(
///   data: page.map(User.fromRow),
///   pagination: Pagination(page: page.page, limit: page.limit),
///   total: page.total,
/// );
/// ```
class DbPage {
  /// The rows of this page.
  final List<Map<String, dynamic>> rows;

  /// Total number of rows matching the query across all pages.
  final int total;

  /// 1-based page number.
  final int page;

  /// Maximum rows per page.
  final int limit;

  const DbPage({
    required this.rows,
    required this.total,
    required this.page,
    required this.limit,
  });

  int get totalPages => total == 0 ? 0 : (total + limit - 1) ~/ limit;

  bool get hasNext => page < totalPages;

  bool get hasPrev => page > 1 && total > 0;

  bool get isEmpty => rows.isEmpty;

  bool get isNotEmpty => rows.isNotEmpty;

  /// Maps every row of this page to [T].
  List<T> map<T>(T Function(Map<String, dynamic> row) mapper) =>
      rows.map(mapper).toList();
}
