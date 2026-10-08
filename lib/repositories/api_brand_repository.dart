import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth_session.dart';
import '../core/supabase_map.dart';
import '../models/brand.dart';
import '../models/brand_query.dart';
import '../models/page_result.dart';
import 'brand_repository.dart';

class ApiBrandRepository implements BrandRepository {
  ApiBrandRepository(this._client, this._auth);

  final SupabaseClient _client;
  final AuthSession _auth;

  static const _select = '*, brand_suppliers(supplier_id)';

  Brand _map(Map<String, dynamic> row) => Brand.fromJson(mapBrandRow(row));

  Future<void> _syncSuppliers(String brandId, List<String> supplierIds) async {
    await _client.from('brand_suppliers').delete().eq('brand_id', brandId);
    if (supplierIds.isEmpty) return;
    await _client.from('brand_suppliers').insert([
      for (final sid in supplierIds) {'brand_id': brandId, 'supplier_id': sid},
    ]);
  }

  @override
  Future<PageResult<Brand>> find(BrandQuery q) async {
    await _auth.ensureLoggedIn();
    return guardSb(() async {
      var query = _client.from('brands').select(_select);
      if (!q.includeDeleted) query = query.eq('deleted', false);
      if (q.search.trim().isNotEmpty) {
        final s = q.search.trim();
        query = query.or('name.ilike.%$s%,country.ilike.%$s%');
      }
      final sort = q.sortField == 'country' ? 'country' : 'name';
      final start = (q.page - 1) * q.size;
      final rows = await query
          .order(sort, ascending: q.sortAscending)
          .range(start, start + q.size - 1);
      var countQ = _client.from('brands').select('id');
      if (!q.includeDeleted) countQ = countQ.eq('deleted', false);
      if (q.search.trim().isNotEmpty) {
        final s = q.search.trim();
        countQ = countQ.or('name.ilike.%$s%,country.ilike.%$s%');
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
  Future<Brand?> findById(String id) async {
    await _auth.ensureLoggedIn();
    try {
      return await guardSb(() async {
        final row =
            await _client.from('brands').select(_select).eq('id', id).single();
        return _map(Map<String, dynamic>.from(row));
      });
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Brand>> findAll({bool includeDeleted = false}) async {
    final page = await find(
      BrandQuery(size: 200, includeDeleted: includeDeleted),
    );
    return page.items;
  }

  @override
  Future<Brand> create(Brand brand) async {
    await _auth.ensureLibrarian();
    return guardSb(() async {
      final row =
          await _client
              .from('brands')
              .insert({
                'name': brand.name,
                'country': brand.country,
                'description': brand.description,
              })
              .select()
              .single();
      final id = row['id'] as String;
      await _syncSuppliers(id, brand.supplierIds);
      return (await findById(id))!;
    });
  }

  @override
  Future<Brand> update(Brand brand) async {
    await _auth.ensureLibrarian();
    return guardSb(() async {
      await _client
          .from('brands')
          .update({
            'name': brand.name,
            'country': brand.country,
            'description': brand.description,
          })
          .eq('id', brand.id);
      await _syncSuppliers(brand.id, brand.supplierIds);
      return (await findById(brand.id))!;
    });
  }

  @override
  Future<void> softDelete(String id) async {
    await _auth.ensureLibrarian();
    await guardSb(
      () => _client
          .from('brands')
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
    await guardSb(() => _client.from('brands').delete().eq('id', id));
  }

  @override
  Future<void> restore(String id) async {
    await _auth.ensureAdmin();
    await guardSb(
      () => _client
          .from('brands')
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
}
