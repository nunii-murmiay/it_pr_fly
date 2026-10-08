import '../core/pb_ids.dart';

class Product {
  final String id;
  final String name;
  final String sku;
  final String supplierId;
  final List<String> categoryIds;
  final List<String> brandIds;
  final double price;
  final int stock;
  final double rating;
  final DateTime? deletedAt;
  final String? supplierName;
  final List<String> brandNames;
  final List<String> categoryNames;

  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.supplierId,
    required this.categoryIds,
    required this.brandIds,
    required this.price,
    required this.stock,
    required this.rating,
    this.deletedAt,
    this.supplierName,
    this.brandNames = const [],
    this.categoryNames = const [],
  });

  bool get isDeleted => deletedAt != null;

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    String? supplierId,
    List<String>? categoryIds,
    List<String>? brandIds,
    double? price,
    int? stock,
    double? rating,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    String? supplierName,
    List<String>? brandNames,
    List<String>? categoryNames,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      supplierId: supplierId ?? this.supplierId,
      categoryIds: categoryIds ?? this.categoryIds,
      brandIds: brandIds ?? this.brandIds,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      rating: rating ?? this.rating,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      supplierName: supplierName ?? this.supplierName,
      brandNames: brandNames ?? this.brandNames,
      categoryNames: categoryNames ?? this.categoryNames,
    );
  }

  /// Тело для POST/PUT (ids, не вложенные объекты).
  Map<String, dynamic> toWriteJson() => {
    'name': name,
    'sku': sku,
    'supplierId': supplierId,
    'categoryIds': categoryIds,
    'brandIds': brandIds,
    'price': price,
    'stock': stock,
    'rating': rating,
  };

  Map<String, dynamic> toJson() => {
    ...toWriteJson(),
    'id': id,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Product.fromJson(Map<String, dynamic> json) {
    final supplier = json['supplier'];
    var supplierId = pbId(json['supplierId']);
    if (supplierId.isEmpty) supplierId = pbId(supplier);

    final brands = json['brands'];
    final categories = json['categories'];

    return Product(
      id: pbId(json['id']),
      name: json['name'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      supplierId: supplierId,
      categoryIds: pbIdList(json['categoryIds'] ?? categories),
      brandIds: pbIdList(json['brandIds'] ?? brands),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      deletedAt: pbDate(json['deletedAt']),
      supplierName: supplier is Map ? supplier['name'] as String? : null,
      brandNames: _names(brands),
      categoryNames: _names(categories),
    );
  }

  static List<String> _names(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => e['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  }
}
