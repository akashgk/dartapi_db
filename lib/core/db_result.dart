class DbResult {
  final List<Map<String, dynamic>> rows;
  final int? affectedRows;
  final dynamic insertId;
  final Duration? executionTime;

  const DbResult({
    required this.rows,
    this.affectedRows,
    this.insertId,
    this.executionTime,
  });

  Map<String, dynamic>? get first => rows.isEmpty ? null : rows.first;
  bool get isEmpty => rows.isEmpty;
  bool get isNotEmpty => rows.isNotEmpty;
}
