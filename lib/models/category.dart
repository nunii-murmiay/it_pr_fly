import '../core/pb_ids.dart';

/// Категория товара (аналог Genre).
class ProductCategory {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final DateTime? deletedAt;

  const ProductCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  ProductCategory copyWith({
    String? id,
    String? name,
    String? description,
    String? iconName,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return ProductCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'iconName': iconName,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory ProductCategory.fromJson(Map<String, dynamic> json) =>
      ProductCategory(
        id: pbId(json['id']),
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        iconName: json['iconName'] as String? ?? 'category',
        deletedAt: pbDate(json['deletedAt']),
      );
}
