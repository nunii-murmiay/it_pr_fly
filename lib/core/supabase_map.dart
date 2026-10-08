import 'api_exceptions.dart';
import 'pb_ids.dart';

/// Приводит snake_case строку Supabase к полям моделей приложения.
Map<String, dynamic> mapSupplierRow(Map<String, dynamic> row) => {
  'id': row['id'],
  'name': row['name'],
  'country': row['country'],
  'contactPerson': row['contact_person'],
  'phone': row['phone'],
  'email': row['email'],
  'rating': row['rating'],
  'deletedAt': row['deleted'] == true ? row['deleted_at'] : null,
};

Map<String, dynamic> mapCategoryRow(Map<String, dynamic> row) => {
  'id': row['id'],
  'name': row['name'],
  'description': row['description'] ?? '',
  'iconName': row['icon_name'] ?? 'category',
  'deletedAt': row['deleted'] == true ? row['deleted_at'] : null,
};

Map<String, dynamic> mapBrandRow(Map<String, dynamic> row) {
  final links = row['brand_suppliers'];
  final supplierIds = <String>[];
  if (links is List) {
    for (final link in links.whereType<Map>()) {
      final id = pbId(link['supplier_id']);
      if (id.isNotEmpty) supplierIds.add(id);
    }
  }
  return {
    'id': row['id'],
    'name': row['name'],
    'country': row['country'],
    'description': row['description'] ?? '',
    'supplierIds': supplierIds,
    'deletedAt': row['deleted'] == true ? row['deleted_at'] : null,
  };
}

Map<String, dynamic> mapProductRow(Map<String, dynamic> row) {
  final supplier = row['suppliers'] ?? row['supplier'];
  final brandLinks = row['product_brands'];
  final categoryLinks = row['product_categories'];
  final brands = <Map<String, dynamic>>[];
  final brandIds = <String>[];
  if (brandLinks is List) {
    for (final link in brandLinks.whereType<Map>()) {
      final b = link['brands'];
      if (b is Map) {
        brands.add(Map<String, dynamic>.from(b));
        brandIds.add(pbId(b['id']));
      } else {
        final id = pbId(link['brand_id']);
        if (id.isNotEmpty) brandIds.add(id);
      }
    }
  }
  final categories = <Map<String, dynamic>>[];
  final categoryIds = <String>[];
  if (categoryLinks is List) {
    for (final link in categoryLinks.whereType<Map>()) {
      final c = link['categories'];
      if (c is Map) {
        categories.add(Map<String, dynamic>.from(c));
        categoryIds.add(pbId(c['id']));
      } else {
        final id = pbId(link['category_id']);
        if (id.isNotEmpty) categoryIds.add(id);
      }
    }
  }
  return {
    'id': row['id'],
    'name': row['name'],
    'sku': row['sku'],
    'supplierId': row['supplier_id'],
    'supplier': supplier,
    'brands': brands,
    'categories': categories,
    'brandIds': brandIds,
    'categoryIds': categoryIds,
    'price': row['price'],
    'stock': row['stock'],
    'rating': row['rating'],
    'deletedAt': row['deleted'] == true ? row['deleted_at'] : null,
  };
}

Map<String, dynamic> mapLoyaltyRow(Map<String, dynamic> row) => {
  'id': row['id'],
  'number': row['number'],
  'issuedAt': row['issued_at'],
  'points': row['points'],
  'level': row['level'],
};

Map<String, dynamic> mapCustomerRow(Map<String, dynamic> row) {
  final cards = row['loyalty_cards'];
  Map<String, dynamic>? card;
  if (cards is List && cards.isNotEmpty && cards.first is Map) {
    card = mapLoyaltyRow(Map<String, dynamic>.from(cards.first as Map));
  } else if (cards is Map) {
    card = mapLoyaltyRow(Map<String, dynamic>.from(cards));
  }
  return {
    'id': row['id'],
    'fullName': row['full_name'],
    'email': row['email'],
    'phone': row['phone'],
    'card': card,
    'deletedAt': row['deleted'] == true ? row['deleted_at'] : null,
  };
}

Map<String, dynamic> mapProfileRow(Map<String, dynamic> row) => {
  'id': row['id'],
  'username': row['username'],
  'fullName': row['full_name'],
  'email': row['email'],
  'role': row['role'],
  'customerId': row['customer_id'],
};

ApiException mapSupabaseError(Object error, [StackTrace? _]) {
  final text = error.toString();
  final lower = text.toLowerCase();
  if (lower.contains('jwt') ||
      lower.contains('not authenticated') ||
      lower.contains('401')) {
    return const UnauthorizedException();
  }
  if (lower.contains('42501') ||
      lower.contains('permission') ||
      lower.contains('row-level security') ||
      lower.contains('403')) {
    return ForbiddenException(_messageFrom(text) ?? 'Недостаточно прав.');
  }
  if (lower.contains('p0001') || lower.contains('недостаточно «')) {
    final productId = _detailUuid(text);
    return ConflictException(
      _messageFrom(text) ?? 'Конфликт остатка.',
      productId: productId,
    );
  }
  if (lower.contains('22023') || lower.contains('балл')) {
    return ValidationException(_messageFrom(text) ?? 'Ошибка валидации', {
      'pointsToRedeem': _messageFrom(text) ?? 'Проверьте баллы',
    });
  }
  if (lower.contains('duplicate') || lower.contains('unique')) {
    return const ValidationException('Такая запись уже есть', {});
  }
  if (lower.contains('socket') ||
      lower.contains('failed host lookup') ||
      lower.contains('network') ||
      lower.contains('connection')) {
    return const NetworkException();
  }
  return ServerException(_messageFrom(text) ?? text);
}

String? _messageFrom(String text) {
  final m = RegExp(r'Exception: (.+)$').firstMatch(text);
  if (m != null) return m.group(1);
  final m2 = RegExp(r'message:\s*(.+)').firstMatch(text);
  return m2?.group(1)?.split('\n').first.trim();
}

String? _detailUuid(String text) {
  final m = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  ).firstMatch(text);
  return m?.group(0);
}

Future<T> guardSb<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on ApiException {
    rethrow;
  } catch (e, st) {
    throw mapSupabaseError(e, st);
  }
}
