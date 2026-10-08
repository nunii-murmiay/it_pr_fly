import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth_session.dart';
import '../core/supabase_map.dart';
import '../models/category.dart';
import '../models/category_query.dart';
import '../models/page_result.dart';
import 'category_repository.dart';

class ApiCategoryRepository implements CategoryRepository {
  ApiCategoryRepository(this._client, this._auth);

  final SupabaseClient _client;
  final AuthSession _auth;

  ProductCategory _map(Map<String, dynamic> row) =>
      ProductCategory.fromJson(mapCategoryRow(row));

  @override
  Future<PageResult<ProductCategory>> find(CategoryQuery q) async {
    await _auth.ensureLoggedIn();
    return guardSb(() async {
      var query = _client.from('categories').select();
      if (!q.includeDeleted) query = query.eq('deleted', false);
      if (q.search.trim().isNotEmpty) {
        final s = q.search.trim();
        query = query.or('name.ilike.%$s%,description.ilike.%$s%');
      }
      final start = (q.page - 1) * q.size;
      final rows = await query.order('name').range(start, start + q.size - 1);
      var countQ = _client.from('categories').select('id');
      if (!q.includeDeleted) countQ = countQ.eq('deleted', false);
      if (q.search.trim().isNotEmpty) {
        final s = q.search.trim();
        countQ = countQ.or('name.ilike.%$s%,description.ilike.%$s%');
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
  Future<ProductCategory?> findById(String id) async {
    await _auth.ensureLoggedIn();
    try {
      return await guardSb(() async {
        final row =
            await _client.from('categories').select().eq('id', id).single();
        return _map(Map<String, dynamic>.from(row));
      });
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ProductCategory>> findAll({bool includeDeleted = false}) async {
    final page = await find(
      CategoryQuery(size: 200, includeDeleted: includeDeleted),
    );
    return page.items;
  }

  @override
  Future<ProductCategory> create(ProductCategory c) async {
    await _auth.ensureLibrarian();
    return guardSb(() async {
      final row =
          await _client
              .from('categories')
              .insert({
                'name': c.name,
                'description': c.description,
                'icon_name': c.iconName,
              })
              .select()
              .single();
      return _map(Map<String, dynamic>.from(row));
    });
  }

  @override
  Future<ProductCategory> update(ProductCategory c) async {
    await _auth.ensureLibrarian();
    return guardSb(() async {
      final row =
          await _client
              .from('categories')
              .update({
                'name': c.name,
                'description': c.description,
                'icon_name': c.iconName,
              })
              .eq('id', c.id)
              .select()
              .single();
      return _map(Map<String, dynamic>.from(row));
    });
  }

  @override
  Future<void> softDelete(String id) async {
    await _auth.ensureLibrarian();
    await guardSb(
      () => _client
          .from('categories')
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
    await guardSb(() => _client.from('categories').delete().eq('id', id));
  }

  @override
  Future<void> restore(String id) async {
    await _auth.ensureAdmin();
    await guardSb(
      () => _client
          .from('categories')
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
