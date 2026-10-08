import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth_session.dart';
import '../core/supabase_map.dart';
import '../models/page_result.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import 'product_repository.dart';

class ApiProductRepository implements ProductRepository {
  ApiProductRepository(this._client, this._auth);

  final SupabaseClient _client;
  final AuthSession _auth;

  static const _select =
      '*, suppliers(*), product_brands(brand_id, brands(*)), product_categories(category_id, categories(*))';

  Product _map(Map<String, dynamic> row) =>
      Product.fromJson(mapProductRow(row));

  Future<void> _syncLinks(
    String productId,
    List<String> brandIds,
    List<String> categoryIds,
  ) async {
    await _client.from('product_brands').delete().eq('product_id', productId);
    await _client
        .from('product_categories')
        .delete()
        .eq('product_id', productId);
    if (brandIds.isNotEmpty) {
      await _client.from('product_brands').insert([
        for (final id in brandIds) {'product_id': productId, 'brand_id': id},
      ]);
    }
    if (categoryIds.isNotEmpty) {
      await _client.from('product_categories').insert([
        for (final id in categoryIds)
          {'product_id': productId, 'category_id': id},
      ]);
    }
  }

  @override
  Future<PageResult<Product>> find(ProductQuery q) async {
    await _auth.ensureLoggedIn();
    return guardSb(() async {
      // Для фильтров по M2M сначала получаем id, затем выбираем товары.
      Set<String>? restrictIds;
      if (q.brandId != null && q.brandId!.isNotEmpty) {
        final links = await _client
            .from('product_brands')
            .select('product_id')
            .eq('brand_id', q.brandId!);
        restrictIds = {
          for (final r in (links as List).whereType<Map>())
            '${r['product_id']}',
        };
      }
      if (q.categoryId != null && q.categoryId!.isNotEmpty) {
        final links = await _client
            .from('product_categories')
            .select('product_id')
            .eq('category_id', q.categoryId!);
        final ids = {
          for (final r in (links as List).whereType<Map>())
            '${r['product_id']}',
        };
        restrictIds = restrictIds == null ? ids : restrictIds.intersection(ids);
      }

      if (restrictIds != null && restrictIds.isEmpty) {
        return PageResult(
          items: const [],
          page: q.page,
          size: q.size,
          total: 0,
        );
      }

      var query = _client.from('products').select(_select);
      if (!q.includeDeleted) query = query.eq('deleted', false);
      if (q.search.trim().isNotEmpty) {
        final s = q.search.trim();
        query = query.or('name.ilike.%$s%,sku.ilike.%$s%');
      }
      if (q.supplierId != null && q.supplierId!.isNotEmpty) {
        query = query.eq('supplier_id', q.supplierId!);
      }
      if (q.priceFrom != null) query = query.gte('price', q.priceFrom!);
      if (q.priceTo != null) query = query.lte('price', q.priceTo!);
      if (restrictIds != null) {
        query = query.inFilter('id', restrictIds.toList());
      }

      final sort = switch (q.sortField) {
        'price' => 'price',
        'stock' => 'stock',
        'rating' => 'rating',
        'sku' => 'sku',
        _ => 'name',
      };
      final start = (q.page - 1) * q.size;
      final rows = await query
          .order(sort, ascending: q.sortAscending)
          .range(start, start + q.size - 1);

      var countQ = _client.from('products').select('id');
      if (!q.includeDeleted) countQ = countQ.eq('deleted', false);
      if (q.search.trim().isNotEmpty) {
        final s = q.search.trim();
        countQ = countQ.or('name.ilike.%$s%,sku.ilike.%$s%');
      }
      if (q.supplierId != null && q.supplierId!.isNotEmpty) {
        countQ = countQ.eq('supplier_id', q.supplierId!);
      }
      if (q.priceFrom != null) countQ = countQ.gte('price', q.priceFrom!);
      if (q.priceTo != null) countQ = countQ.lte('price', q.priceTo!);
      if (restrictIds != null) {
        countQ = countQ.inFilter('id', restrictIds.toList());
      }
      final total = ((await countQ) as List).length;

      return PageResult(
        items:
            (rows as List)
                .whereType<Map>()
                .map((e) => _map(Map<String, dynamic>.from(e)))
                .toList(),
        page: q.page,
        size: q.size,
        total: total,
      );
    });
  }

  @override
  Future<Product?> findById(String id) async {
    await _auth.ensureLoggedIn();
    try {
      return await guardSb(() async {
        final row =
            await _client
                .from('products')
                .select(_select)
                .eq('id', id)
                .single();
        return _map(Map<String, dynamic>.from(row));
      });
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Product>> findAll({bool includeDeleted = false}) async {
    final page = await find(
      ProductQuery(size: 200, includeDeleted: includeDeleted),
    );
    return page.items;
  }

  @override
  Future<Product> create(Product product) async {
    await _auth.ensureLibrarian();
    return guardSb(() async {
      final row =
          await _client
              .from('products')
              .insert({
                'name': product.name,
                'sku': product.sku,
                'supplier_id': product.supplierId,
                'price': product.price,
                'stock': product.stock,
                'rating': product.rating,
              })
              .select()
              .single();
      final id = row['id'] as String;
      await _syncLinks(id, product.brandIds, product.categoryIds);
      return (await findById(id))!;
    });
  }

  @override
  Future<Product> update(Product product) async {
    await _auth.ensureLibrarian();
    return guardSb(() async {
      await _client
          .from('products')
          .update({
            'name': product.name,
            'sku': product.sku,
            'supplier_id': product.supplierId,
            'price': product.price,
            'stock': product.stock,
            'rating': product.rating,
          })
          .eq('id', product.id);
      await _syncLinks(product.id, product.brandIds, product.categoryIds);
      return (await findById(product.id))!;
    });
  }

  @override
  Future<void> softDelete(String id) async {
    await _auth.ensureLibrarian();
    await guardSb(
      () => _client
          .from('products')
          .update({
            'deleted': true,
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id),
    );
  }

  @override
  Future<void> hardDelete(String id) async {
    await _auth.ensureAdmin();
    await guardSb(() => _client.from('products').delete().eq('id', id));
  }

  @override
  Future<void> restore(String id) async {
    await _auth.ensureAdmin();
    await guardSb(
      () => _client
          .from('products')
          .update({'deleted': false, 'deleted_at': null})
          .eq('id', id),
    );
  }

  @override
  Future<int> deleteMany(List<String> ids) async {
    var n = 0;
    for (final id in ids) {
      await softDelete(id);
      n++;
    }
    return n;
  }

  @override
  Future<int> restoreMany(List<String> ids) async {
    var n = 0;
    for (final id in ids) {
      await restore(id);
      n++;
    }
    return n;
  }

  @override
  Future<bool> isSkuTaken(String sku, {String? excludeId}) async {
    await _auth.ensureLoggedIn();
    return guardSb(() async {
      var q = _client
          .from('products')
          .select('id')
          .eq('sku', sku)
          .eq('deleted', false);
      final rows = await q;
      for (final r in (rows as List).whereType<Map>()) {
        if (excludeId == null || r['id'] != excludeId) return true;
      }
      return false;
    });
  }

  @override
  Future<int> countBySupplier(
    String supplierId, {
    bool includeDeleted = false,
  }) async {
    return guardSb(() async {
      var q = _client
          .from('products')
          .select('id')
          .eq('supplier_id', supplierId);
      if (!includeDeleted) q = q.eq('deleted', false);
      return ((await q) as List).length;
    });
  }

  @override
  Future<int> countByBrand(
    String brandId, {
    bool includeDeleted = false,
  }) async {
    return guardSb(() async {
      final links = await _client
          .from('product_brands')
          .select('product_id')
          .eq('brand_id', brandId);
      final ids = [
        for (final r in (links as List).whereType<Map>()) '${r['product_id']}',
      ];
      if (ids.isEmpty) return 0;
      if (includeDeleted) return ids.length;
      final rows = await _client
          .from('products')
          .select('id')
          .inFilter('id', ids)
          .eq('deleted', false);
      return (rows as List).length;
    });
  }

  @override
  Future<int> countByCategory(
    String categoryId, {
    bool includeDeleted = false,
  }) async {
    return guardSb(() async {
      final links = await _client
          .from('product_categories')
          .select('product_id')
          .eq('category_id', categoryId);
      final ids = [
        for (final r in (links as List).whereType<Map>()) '${r['product_id']}',
      ];
      if (ids.isEmpty) return 0;
      if (includeDeleted) return ids.length;
      final rows = await _client
          .from('products')
          .select('id')
          .inFilter('id', ids)
          .eq('deleted', false);
      return (rows as List).length;
    });
  }
}
