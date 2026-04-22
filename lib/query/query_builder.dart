import '../core/dartapi_db_core.dart';
import '../core/db_result.dart';

class _Condition {
  final String column;
  final String op;
  final Object? value;
  const _Condition(this.column, this.op, this.value);
}

/// A fluent SELECT query builder.
///
/// Obtain one via [DartApiDB.query] (imported from `dartapi_db`):
/// ```dart
/// final rows = await db.query('users')
///     .where('age', greaterThan: 18)
///     .where('status', equals: 'active')
///     .orderBy('name')
///     .limit(20)
///     .offset(0)
///     .get();
///
/// final user = await db.query('users').where('id', equals: id).first();
/// final total = await db.query('users').where('role', equals: 'admin').count();
/// ```
class QueryBuilder {
  final DartApiDB _db;
  final String _table;
  final DbParamStyle _style;

  List<String>? _selectColumns;
  final List<_Condition> _conditions = [];
  final List<({String column, bool ascending})> _orderBys = [];
  int? _limit;
  int? _offset;

  QueryBuilder(this._db, this._table) : _style = _db.paramStyle;

  /// Restricts SELECT to specific [columns]. Default is `*`.
  QueryBuilder select(List<String> columns) {
    _selectColumns = columns;
    return this;
  }

  /// Adds a WHERE condition. Pass exactly one named argument per call.
  ///
  /// ```dart
  /// .where('age', greaterThan: 18)
  /// .where('email', like: '%@corp.com')
  /// .where('role', whereIn: ['admin', 'editor'])
  /// .where('deleted_at', isNull: true)
  /// ```
  QueryBuilder where(
    String column, {
    Object? equals,
    Object? notEquals,
    Object? greaterThan,
    Object? lessThan,
    Object? greaterThanOrEqual,
    Object? lessThanOrEqual,
    String? like,
    List<Object?>? whereIn,
    bool isNull = false,
    bool isNotNull = false,
  }) {
    if (isNull) {
      _conditions.add(_Condition(column, 'IS NULL', null));
    } else if (isNotNull) {
      _conditions.add(_Condition(column, 'IS NOT NULL', null));
    } else if (equals != null) {
      _conditions.add(_Condition(column, '=', equals));
    } else if (notEquals != null) {
      _conditions.add(_Condition(column, '!=', notEquals));
    } else if (greaterThan != null) {
      _conditions.add(_Condition(column, '>', greaterThan));
    } else if (lessThan != null) {
      _conditions.add(_Condition(column, '<', lessThan));
    } else if (greaterThanOrEqual != null) {
      _conditions.add(_Condition(column, '>=', greaterThanOrEqual));
    } else if (lessThanOrEqual != null) {
      _conditions.add(_Condition(column, '<=', lessThanOrEqual));
    } else if (like != null) {
      _conditions.add(_Condition(column, 'LIKE', like));
    } else if (whereIn != null) {
      _conditions.add(_Condition(column, 'IN', whereIn));
    }
    return this;
  }

  /// Adds an ORDER BY clause. Call multiple times for multi-column sort.
  QueryBuilder orderBy(String column, {bool ascending = true}) {
    _orderBys.add((column: column, ascending: ascending));
    return this;
  }

  /// Limits the number of rows returned.
  QueryBuilder limit(int n) {
    _limit = n;
    return this;
  }

  /// Skips the first [n] matching rows (offset-based pagination).
  QueryBuilder offset(int n) {
    _offset = n;
    return this;
  }

  /// Executes the query and returns all matching rows as a [DbResult].
  Future<DbResult> get() {
    final (sql, params) = _buildSelect();
    return _db.rawQuery(sql, values: params);
  }

  /// Returns the first matching row, or `null` if none match.
  Future<Map<String, dynamic>?> first() async => (await get()).first;

  /// Returns the number of rows matching the current WHERE conditions.
  ///
  /// ORDER BY, LIMIT, and OFFSET are ignored.
  Future<int> count() async {
    final params = <String, dynamic>{};
    var sql = 'SELECT COUNT(*) AS _count FROM $_table';
    if (_conditions.isNotEmpty) {
      sql += ' WHERE ${_buildWhere(params)}';
    }
    final result =
        await _db.rawQuery(sql, values: params.isEmpty ? null : params);
    final val = result.first?['_count'] ??
        result.first?['count(*)'] ??
        result.first?['COUNT(*)'];
    return switch (val) {
      int v => v,
      _ => int.tryParse('$val') ?? 0,
    };
  }

  // ── Internal builders ──────────────────────────────────────────────────────

  (String, Map<String, dynamic>?) _buildSelect() {
    final params = <String, dynamic>{};
    final cols = _selectColumns?.join(', ') ?? '*';
    var sql = 'SELECT $cols FROM $_table';

    if (_conditions.isNotEmpty) {
      sql += ' WHERE ${_buildWhere(params)}';
    }

    if (_orderBys.isNotEmpty) {
      final order = _orderBys
          .map((o) => '${o.column} ${o.ascending ? 'ASC' : 'DESC'}')
          .join(', ');
      sql += ' ORDER BY $order';
    }

    // SQLite requires LIMIT when OFFSET is present; use -1 for unlimited.
    if (_limit != null) {
      sql += ' LIMIT $_limit';
      if (_offset != null) sql += ' OFFSET $_offset';
    } else if (_offset != null) {
      sql += ' LIMIT -1 OFFSET $_offset';
    }

    return (sql, params.isEmpty ? null : params);
  }

  String _buildWhere(Map<String, dynamic> params) {
    final parts = <String>[];
    var idx = 0;

    for (final c in _conditions) {
      switch (c.op) {
        case 'IS NULL':
          parts.add('${c.column} IS NULL');
        case 'IS NOT NULL':
          parts.add('${c.column} IS NOT NULL');
        case 'IN':
          final values = c.value as List<Object?>;
          if (_style == DbParamStyle.positional) {
            for (var i = 0; i < values.length; i++) {
              params['p${idx}_$i'] = values[i];
            }
            parts.add(
              '${c.column} IN (${List.filled(values.length, '?').join(', ')})',
            );
          } else {
            final pfx = _style == DbParamStyle.named ? '@' : ':';
            final keys = List.generate(values.length, (i) => 'p${idx}_$i');
            for (var i = 0; i < values.length; i++) {
              params[keys[i]] = values[i];
            }
            parts.add(
              '${c.column} IN (${keys.map((k) => '$pfx$k').join(', ')})',
            );
          }
        default:
          final key = 'p$idx';
          params[key] = c.value;
          if (_style == DbParamStyle.positional) {
            parts.add('${c.column} ${c.op} ?');
          } else {
            final pfx = _style == DbParamStyle.named ? '@' : ':';
            parts.add('${c.column} ${c.op} $pfx$key');
          }
      }
      idx++;
    }

    return parts.join(' AND ');
  }
}
