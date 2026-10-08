import 'package:shared_preferences/shared_preferences.dart';
import '../models/page_result.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import '../models/seed_data.dart';
import 'prefs_store.dart';
import 'product_repository.dart';

class PersistentProductRepository implements ProductRepository {
  late final PrefsStore<Product> _store;
  late List<Product> _items;
  late int _nextId;
  final void Function(String message)? onStorageNotice;

  PersistentProductRepository(SharedPreferences prefs, {this.onStorageNotice}) {
    _store = PrefsStore<Product>(
      prefs: prefs,
      key: 'products_v2',
      legacyKey: 'products_v1',
      fromJson: Product.fromJson,
      toJson: (p) => p.toJson(),
      seed: seedProducts,
      onMigrated: onStorageNotice,
    );
    _items = _store.restore();
    _nextId =
        _items.fold<int>(0, (m, e) {
          final n = int.tryParse(e.id) ?? 0;
          return n > m ? n : m;
        }) +
        1;
  }

  Future<void> _save() => _store.persist(_items);

  @override
  Future<PageResult<Product>> find(ProductQuery q) async {
    await Future.delayed(const Duration(milliseconds: 120));
    var rows = _items.where((p) => q.includeDeleted || !p.isDeleted).toList();

    if (q.search.trim().isNotEmpty) {
      final needle = q.search.trim().toLowerCase();
      rows =
          rows
              .where(
                (p) =>
                    p.name.toLowerCase().contains(needle) ||
                    p.sku.toLowerCase().contains(needle),
              )
              .toList();
    }
    if (q.categoryId != null) {
      rows = rows.where((p) => p.categoryIds.contains(q.categoryId)).toList();
    }
    if (q.brandId != null) {
      rows = rows.where((p) => p.brandIds.contains(q.brandId)).toList();
    }
    if (q.supplierId != null) {
      rows = rows.where((p) => p.supplierId == q.supplierId).toList();
    }
    if (q.priceFrom != null) {
      rows = rows.where((p) => p.price >= q.priceFrom!).toList();
    }
    if (q.priceTo != null) {
      rows = rows.where((p) => p.price <= q.priceTo!).toList();
    }

    rows.sort((a, b) {
      final result = switch (q.sortField) {
        'price' => a.price.compareTo(b.price),
        'stock' => a.stock.compareTo(b.stock),
        'rating' => a.rating.compareTo(b.rating),
        'sku' => a.sku.toLowerCase().compareTo(b.sku.toLowerCase()),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
      return q.sortAscending ? result : -result;
    });

    final total = rows.length;
    final from = (q.page - 1) * q.size;
    final to = (from + q.size) > total ? total : (from + q.size);
    final pageItems = from >= total ? <Product>[] : rows.sublist(from, to);
    return PageResult(
      items: pageItems,
      page: q.page,
      size: q.size,
      total: total,
    );
  }

  @override
  Future<Product?> findById(String id) async {
    final i = _items.indexWhere((p) => p.id == id);
    return i == -1 ? null : _items[i];
  }

  @override
  Future<List<Product>> findAll({bool includeDeleted = false}) async {
    return _items.where((p) => includeDeleted || !p.isDeleted).toList();
  }

  @override
  Future<Product> create(Product product) async {
    final created = product.copyWith(
      id: '${_nextId++}',
      sku:
          product.sku.isEmpty
              ? 'PET-${1000 + _nextId}'
              : product.sku.trim().toUpperCase(),
    );
    _items.add(created);
    await _save();
    return created;
  }

  @override
  Future<Product> update(Product product) async {
    final i = _items.indexWhere((p) => p.id == product.id);
    if (i == -1) throw StateError('Товар ${product.id} не найден');
    _items[i] = product.copyWith(sku: product.sku.trim().toUpperCase());
    await _save();
    return _items[i];
  }

  @override
  Future<void> softDelete(String id) async {
    final i = _items.indexWhere((p) => p.id == id);
    if (i == -1) throw StateError('Товар $id не найден');
    _items[i] = _items[i].copyWith(deletedAt: DateTime.now());
    await _save();
  }

  @override
  Future<void> hardDelete(String id) async {
    _items.removeWhere((p) => p.id == id);
    await _save();
  }

  @override
  Future<void> restore(String id) async {
    final i = _items.indexWhere((p) => p.id == id);
    if (i == -1) throw StateError('Товар $id не найден');
    _items[i] = _items[i].copyWith(clearDeletedAt: true);
    await _save();
  }

  @override
  Future<int> deleteMany(List<String> ids) async {
    var count = 0;
    for (final id in ids) {
      final i = _items.indexWhere((p) => p.id == id && !p.isDeleted);
      if (i != -1) {
        _items[i] = _items[i].copyWith(deletedAt: DateTime.now());
        count++;
      }
    }
    await _save();
    return count;
  }

  @override
  Future<int> restoreMany(List<String> ids) async {
    var count = 0;
    for (final id in ids) {
      final i = _items.indexWhere((p) => p.id == id && p.isDeleted);
      if (i != -1) {
        _items[i] = _items[i].copyWith(clearDeletedAt: true);
        count++;
      }
    }
    await _save();
    return count;
  }

  @override
  Future<bool> isSkuTaken(String sku, {String? excludeId}) async {
    final needle = sku.trim().toUpperCase();
    return _items.any(
      (p) =>
          !p.isDeleted &&
          p.sku.toUpperCase() == needle &&
          (excludeId == null || p.id != excludeId),
    );
  }

  @override
  Future<int> countBySupplier(
    String supplierId, {
    bool includeDeleted = false,
  }) async {
    return _items
        .where(
          (p) => p.supplierId == supplierId && (includeDeleted || !p.isDeleted),
        )
        .length;
  }

  @override
  Future<int> countByBrand(
    String brandId, {
    bool includeDeleted = false,
  }) async {
    return _items
        .where(
          (p) =>
              p.brandIds.contains(brandId) && (includeDeleted || !p.isDeleted),
        )
        .length;
  }

  @override
  Future<int> countByCategory(
    String categoryId, {
    bool includeDeleted = false,
  }) async {
    return _items
        .where(
          (p) =>
              p.categoryIds.contains(categoryId) &&
              (includeDeleted || !p.isDeleted),
        )
        .length;
  }
}
