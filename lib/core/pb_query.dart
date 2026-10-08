import 'pb_ids.dart';

/// Сборка filter/sort/page для PocketBase list API.
class PbListQuery {
  PbListQuery({
    this.page = 1,
    this.perPage = 10,
    this.sort = 'name',
    this.filterParts = const [],
    this.expand,
    this.includeDeleted = false,
  });

  final int page;
  final int perPage;
  final String sort;
  final List<String> filterParts;
  final String? expand;
  final bool includeDeleted;

  Map<String, dynamic> toParams() {
    final parts = [...filterParts];
    if (!includeDeleted) {
      parts.add('deleted = false');
    }
    return {
      'page': page,
      'perPage': perPage,
      'sort': sort,
      if (parts.isNotEmpty) 'filter': parts.join(' && '),
      if (expand != null && expand!.isNotEmpty) 'expand': expand,
    };
  }
}

String pbSort(String field, bool ascending) => ascending ? field : '-$field';

String pbEscape(String value) =>
    value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

String pbSearchFilter(String search, List<String> fields) {
  final q = search.trim();
  if (q.isEmpty || fields.isEmpty) return '';
  final esc = pbEscape(q);
  return '(${fields.map((f) => '$f ~ "$esc"').join(' || ')})';
}

String pbRelationEquals(String field, String? id) {
  if (id == null || id.isEmpty) return '';
  return '$field = "${pbEscape(id)}"';
}

String pbRelationContains(String field, String? id) {
  if (id == null || id.isEmpty) return '';
  return '$field.id ?= "${pbEscape(id)}"';
}

Map<String, dynamic> pbPageResult(Map<String, dynamic> data) => {
  'items': data['items'] ?? const [],
  'page': data['page'] ?? 1,
  'size': data['perPage'] ?? data['size'] ?? 10,
  'total': data['totalItems'] ?? data['total'] ?? 0,
};

/// Нормализация записи PB → json, понятный моделям приложения.
Map<String, dynamic> pbRecordToApp(
  Map<String, dynamic> record, {
  String? supplierKey = 'supplier',
  String? brandsKey = 'brands',
  String? categoriesKey = 'categories',
}) {
  final expand =
      record['expand'] is Map
          ? Map<String, dynamic>.from(record['expand'] as Map)
          : const <String, dynamic>{};

  final deletedAt = record['deletedAt'];
  final deleted = record['deleted'] == true;

  final out = Map<String, dynamic>.from(record);
  out['id'] = pbId(record['id']);
  out['deletedAt'] =
      deletedAt != null && '$deletedAt'.isNotEmpty
          ? deletedAt
          : (deleted ? DateTime.now().toIso8601String() : null);

  if (supplierKey != null) {
    final supplier = expand[supplierKey] ?? record[supplierKey];
    if (supplier is Map) {
      out['supplier'] = Map<String, dynamic>.from(supplier);
      out['supplierId'] = pbId(supplier['id']);
    } else if (supplier != null) {
      out['supplierId'] = pbId(supplier);
    }
  }

  if (brandsKey != null) {
    final brands = expand[brandsKey] ?? record[brandsKey];
    out['brands'] = brands;
    out['brandIds'] = pbIdList(brands);
  }

  if (categoriesKey != null) {
    final categories = expand[categoriesKey] ?? record[categoriesKey];
    out['categories'] = categories;
    out['categoryIds'] = pbIdList(categories);
  }

  if (record.containsKey('suppliers')) {
    out['supplierIds'] = pbIdList(expand['suppliers'] ?? record['suppliers']);
  }

  return out;
}
