import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api_exceptions.dart';
import '../core/auth_session.dart';
import '../core/supabase_map.dart';
import '../models/page_result.dart';
import '../models/supplier.dart';
import '../models/supplier_query.dart';
import 'supplier_repository.dart';

class ApiSupplierRepository implements SupplierRepository {
  ApiSupplierRepository(this._client, this._auth);

  final SupabaseClient _client;
  final AuthSession _auth;

  Supplier _map(Map<String, dynamic> row) =>
      Supplier.fromJson(mapSupplierRow(row));

  @override
  Future<PageResult<Supplier>> find(SupplierQuery q) async {
    await _auth.ensureLoggedIn();
    return guardSb(() async {
      var query = _client.from('suppliers').select();
      if (!q.includeDeleted) {
        query = query.eq('deleted', false);
      }
      if (q.search.trim().isNotEmpty) {
        final s = q.search.trim();
        query = query.or('name.ilike.%$s%,country.ilike.%$s%,email.ilike.%$s%');
      }
      if (q.country != null && q.country!.isNotEmpty) {
        query = query.eq('country', q.country!);
      }
      final ascending = q.sortAscending;
      final sort = switch (q.sortField) {
        'country' => 'country',
        'rating' => 'rating',
        _ => 'name',
      };
      final start = (q.page - 1) * q.size;
      final end = start + q.size - 1;
      final rows = await query
          .order(sort, ascending: ascending)
          .range(start, end);
      // count
      var countQ = _client.from('suppliers').select('id');
      if (!q.includeDeleted) countQ = countQ.eq('deleted', false);
      if (q.search.trim().isNotEmpty) {
        final s = q.search.trim();
        countQ = countQ.or(
          'name.ilike.%$s%,country.ilike.%$s%,email.ilike.%$s%',
        );
      }
      if (q.country != null && q.country!.isNotEmpty) {
        countQ = countQ.eq('country', q.country!);
      }
      final all = await countQ;
      final total = (all as List).length;
      final items =
          (rows as List)
              .whereType<Map>()
              .map((e) => _map(Map<String, dynamic>.from(e)))
              .toList();
      return PageResult(items: items, page: q.page, size: q.size, total: total);
    });
  }

  @override
  Future<Supplier?> findById(String id) async {
    await _auth.ensureLoggedIn();
    try {
      return await guardSb(() async {
        final row =
            await _client.from('suppliers').select().eq('id', id).single();
        return _map(Map<String, dynamic>.from(row));
      });
    } on NotFoundException {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Supplier>> findAll({bool includeDeleted = false}) async {
    final page = await find(
      SupplierQuery(size: 200, includeDeleted: includeDeleted),
    );
    return page.items;
  }

  @override
  Future<Supplier> create(Supplier s) async {
    await _auth.ensureLibrarian();
    return guardSb(() async {
      final row =
          await _client
              .from('suppliers')
              .insert({
                'name': s.name,
                'country': s.country,
                'contact_person': s.contactPerson,
                'phone': s.phone,
                'email': s.email,
                'rating': s.rating,
              })
              .select()
              .single();
      return _map(Map<String, dynamic>.from(row));
    });
  }

  @override
  Future<Supplier> update(Supplier s) async {
    await _auth.ensureLibrarian();
    return guardSb(() async {
      final row =
          await _client
              .from('suppliers')
              .update({
                'name': s.name,
                'country': s.country,
                'contact_person': s.contactPerson,
                'phone': s.phone,
                'email': s.email,
                'rating': s.rating,
              })
              .eq('id', s.id)
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
          .from('suppliers')
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
    await guardSb(() => _client.from('suppliers').delete().eq('id', id));
  }

  @override
  Future<void> restore(String id) async {
    await _auth.ensureAdmin();
    await guardSb(
      () => _client
          .from('suppliers')
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
