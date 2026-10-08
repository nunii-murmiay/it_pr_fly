import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth_session.dart';
import '../core/pb_ids.dart';
import '../core/supabase_map.dart';
import '../models/customer.dart';
import '../models/customer_query.dart';
import '../models/page_result.dart';
import 'customer_repository.dart';

class ApiCustomerRepository implements CustomerRepository {
  ApiCustomerRepository(this._client, this._auth);

  final SupabaseClient _client;
  final AuthSession _auth;

  static const _select = '*, loyalty_cards(*)';

  Customer _map(Map<String, dynamic> row) =>
      Customer.fromJson(mapCustomerRow(row));

  @override
  Future<PageResult<Customer>> find(CustomerQuery q) async {
    await _auth.ensureLoggedIn();
    return guardSb(() async {
      var query = _client.from('customers').select(_select);
      if (!q.includeDeleted) query = query.eq('deleted', false);
      if (q.search.trim().isNotEmpty) {
        final s = q.search.trim();
        query = query.or(
          'full_name.ilike.%$s%,email.ilike.%$s%,phone.ilike.%$s%',
        );
      }
      final sort = switch (q.sortField) {
        'email' => 'email',
        'phone' => 'phone',
        _ => 'full_name',
      };
      final start = (q.page - 1) * q.size;
      final rows = await query
          .order(sort, ascending: q.sortAscending)
          .range(start, start + q.size - 1);

      var items =
          (rows as List)
              .whereType<Map>()
              .map((e) => _map(Map<String, dynamic>.from(e)))
              .toList();
      if (q.cardLevel != null && q.cardLevel!.isNotEmpty) {
        items = items.where((c) => c.card.level == q.cardLevel).toList();
      }

      var countQ = _client.from('customers').select('id');
      if (!q.includeDeleted) countQ = countQ.eq('deleted', false);
      if (q.search.trim().isNotEmpty) {
        final s = q.search.trim();
        countQ = countQ.or(
          'full_name.ilike.%$s%,email.ilike.%$s%,phone.ilike.%$s%',
        );
      }
      var total = ((await countQ) as List).length;
      if (q.cardLevel != null && q.cardLevel!.isNotEmpty) {
        total = items.length;
      }

      return PageResult(items: items, page: q.page, size: q.size, total: total);
    });
  }

  @override
  Future<Customer?> findById(String id) async {
    await _auth.ensureLoggedIn();
    try {
      return await guardSb(() async {
        final row =
            await _client
                .from('customers')
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
  Future<List<Customer>> findAll({bool includeDeleted = false}) async {
    final page = await find(
      CustomerQuery(size: 200, includeDeleted: includeDeleted),
    );
    return page.items;
  }

  @override
  Future<Customer> create(Customer customer) async {
    await _auth.ensureLibrarian();
    return guardSb(() async {
      final row =
          await _client
              .from('customers')
              .insert({
                'full_name': customer.fullName,
                'email': customer.email,
                'phone': customer.phone,
              })
              .select()
              .single();
      final id = row['id'] as String;
      await _client.from('loyalty_cards').insert({
        'number':
            customer.card.number.isNotEmpty
                ? customer.card.number
                : 'LC-${id.substring(0, 8).toUpperCase()}',
        'points': customer.card.points,
        'level': customer.card.level,
        'customer_id': id,
        'issued_at': customer.card.issuedAt.toUtc().toIso8601String(),
      });
      return (await findById(id))!;
    });
  }

  @override
  Future<Customer> update(Customer customer) async {
    await _auth.ensureLibrarian();
    return guardSb(() async {
      await _client
          .from('customers')
          .update({
            'full_name': customer.fullName,
            'email': customer.email,
            'phone': customer.phone,
          })
          .eq('id', customer.id);
      await _client
          .from('loyalty_cards')
          .update({
            'number': customer.card.number,
            'points': customer.card.points,
            'level': customer.card.level,
          })
          .eq('customer_id', customer.id);
      return (await findById(customer.id))!;
    });
  }

  @override
  Future<void> softDelete(String id) async {
    await _auth.ensureLibrarian();
    await guardSb(
      () => _client
          .from('customers')
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
    await guardSb(() => _client.from('customers').delete().eq('id', id));
  }

  @override
  Future<void> restore(String id) async {
    await _auth.ensureAdmin();
    await guardSb(
      () => _client
          .from('customers')
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
  Future<bool> isEmailTaken(String email, {String? excludeId}) async {
    await _auth.ensureLoggedIn();
    return guardSb(() async {
      final rows = await _client
          .from('customers')
          .select('id')
          .ilike('email', email.trim());
      for (final r in (rows as List).whereType<Map>()) {
        if (excludeId == null || r['id'] != excludeId) return true;
      }
      return false;
    });
  }
}

class ApiSalesRepository {
  ApiSalesRepository(this._client, this._auth);

  final SupabaseClient _client;
  final AuthSession _auth;

  Future<Map<String, dynamic>> createSale({
    required String customerId,
    required List<({String productId, int quantity})> items,
    int pointsToRedeem = 0,
  }) async {
    await _auth.ensureLibrarian();
    return guardSb(() async {
      final payload = [
        for (final i in items)
          {'product_id': i.productId, 'quantity': i.quantity},
      ];
      final raw = await _client.rpc(
        'create_sale',
        params: {
          'p_customer_id': customerId,
          'p_items': payload,
          'p_points_to_redeem': pointsToRedeem < 0 ? 0 : pointsToRedeem,
        },
      );
      return Map<String, dynamic>.from(raw as Map);
    });
  }

  Future<void> createSaleLine({
    required String customerId,
    required String productId,
    required int quantity,
  }) async {
    await createSale(
      customerId: customerId,
      items: [(productId: productId, quantity: quantity)],
    );
  }

  Future<List<Map<String, dynamic>>> listSales({int size = 50}) async {
    await _auth.ensureLoggedIn();
    return guardSb(() async {
      final rows = await _client
          .from('sales')
          .select('*, customers(*)')
          .eq('deleted', false)
          .order('created_at', ascending: false)
          .limit(size);
      final result = <Map<String, dynamic>>[];
      for (final raw in (rows as List).whereType<Map>()) {
        result.add(await _mapSale(Map<String, dynamic>.from(raw)));
      }
      return result;
    });
  }

  Future<Map<String, dynamic>> getSale(String id) async {
    await _auth.ensureLoggedIn();
    return guardSb(() async {
      final row =
          await _client
              .from('sales')
              .select('*, customers(*)')
              .eq('id', id)
              .single();
      return _mapSale(Map<String, dynamic>.from(row));
    });
  }

  Future<Map<String, dynamic>> _mapSale(Map<String, dynamic> sale) async {
    final saleId = pbId(sale['id']);
    final itemsRes = await _client
        .from('sale_items')
        .select('*, products(*)')
        .eq('sale_id', saleId)
        .eq('deleted', false);
    final lineItems =
        (itemsRes as List).whereType<Map>().map((e) {
          final m = Map<String, dynamic>.from(e);
          final product = m['products'];
          return {
            ...m,
            'product': product,
            'productId': pbId(m['product_id']),
            'quantity': m['quantity'],
            'unitPrice': m['unit_price'],
          };
        }).toList();
    final customer = sale['customers'];
    return {
      'id': saleId,
      'customerId': pbId(sale['customer_id']),
      'customer':
          customer is Map
              ? {
                'id': customer['id'],
                'fullName': customer['full_name'],
                'phone': customer['phone'],
                'email': customer['email'],
              }
              : null,
      'total': sale['total'],
      'pointsEarned': sale['points_earned'],
      'pointsRedeemed': sale['points_redeemed'],
      'items': lineItems,
      'product': lineItems.isNotEmpty ? lineItems.first['product'] : null,
      'quantity': lineItems.isNotEmpty ? lineItems.first['quantity'] : null,
    };
  }
}
