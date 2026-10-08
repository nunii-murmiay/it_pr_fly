import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exceptions.dart';
import '../core/auth_session.dart';
import '../core/pb_ids.dart';
import '../core/pb_query.dart';
import '../models/customer.dart';
import '../models/customer_query.dart';
import '../models/loyalty_card.dart';
import '../models/page_result.dart';
import 'customer_repository.dart';

class ApiCustomerRepository implements CustomerRepository {
  ApiCustomerRepository(this._dio, this._auth);
  final Dio _dio;
  final AuthSession _auth;
  CancelToken? _findToken;

  static const _path = '/collections/customers/records';
  static const _cards = '/collections/loyalty_cards/records';

  Future<Map<String, LoyaltyCard>> _cardsByCustomer({
    String? customerId,
    String? level,
  }) async {
    final parts = <String>[
      if (customerId != null && customerId.isNotEmpty)
        'customer = "${pbEscape(customerId)}"',
      if (level != null && level.isNotEmpty) 'level = "${pbEscape(level)}"',
      '(deleted = false || deleted = null)',
    ];
    final response = await _dio.get(
      _cards,
      queryParameters: {
        'page': 1,
        'perPage': 200,
        'filter': parts.join(' && '),
      },
    );
    final items = (response.data as Map)['items'] as List? ?? const [];
    final map = <String, LoyaltyCard>{};
    for (final raw in items.whereType<Map>()) {
      final m = Map<String, dynamic>.from(raw);
      final cid = pbId(m['customer']);
      map[cid] = LoyaltyCard.fromJson({
        'id': pbId(m['id']),
        'number': m['number'],
        'issuedAt': m['issuedAt'],
        'points': m['points'],
        'level': m['level'],
      });
    }
    return map;
  }

  Customer _map(Map<String, dynamic> raw, LoyaltyCard? card) {
    final base = pbRecordToApp(raw);
    base['card'] =
        card?.toJson() ??
        {
          'number': '',
          'issuedAt': DateTime.now().toIso8601String(),
          'points': 0,
          'level': 'Стандарт',
        };
    return Customer.fromJson(base);
  }

  @override
  Future<PageResult<Customer>> find(CustomerQuery q) async {
    await _auth.ensureLoggedIn();
    _findToken?.cancel('устаревший поиск');
    _findToken = CancelToken();
    final token = _findToken!;

    return guardRead(() async {
      final cards = await _cardsByCustomer(level: q.cardLevel);
      final allowedIds =
          q.cardLevel == null || q.cardLevel!.isEmpty
              ? null
              : cards.keys.toSet();

      final parts =
          <String>[
            if (q.search.trim().isNotEmpty)
              pbSearchFilter(q.search, const ['fullName', 'email', 'phone']),
          ].where((e) => e.isNotEmpty).toList();

      final response = await _dio.get(
        _path,
        queryParameters:
            PbListQuery(
              page: q.page,
              perPage: q.size,
              sort: pbSort(q.sortField, q.sortAscending),
              filterParts: parts,
              includeDeleted: q.includeDeleted,
            ).toParams(),
        cancelToken: token,
      );
      final mapped = pbPageResult(
        Map<String, dynamic>.from(response.data as Map),
      );
      var items =
          (mapped['items'] as List).whereType<Map>().map((e) {
            final id = pbId(e['id']);
            return _map(Map<String, dynamic>.from(e), cards[id]);
          }).toList();
      if (allowedIds != null) {
        items = items.where((c) => allowedIds.contains(c.id)).toList();
      }
      return PageResult(
        items: items,
        page: (mapped['page'] as num).toInt(),
        size: (mapped['size'] as num).toInt(),
        total:
            allowedIds == null
                ? (mapped['total'] as num).toInt()
                : items.length,
      );
    });
  }

  @override
  Future<Customer?> findById(String id) async {
    await _auth.ensureLoggedIn();
    try {
      return await guardRead(() async {
        final r = await _dio.get('$_path/$id');
        final cards = await _cardsByCustomer(customerId: id);
        return _map(Map<String, dynamic>.from(r.data as Map), cards[id]);
      });
    } on NotFoundException {
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

  Future<void> _upsertCard(Customer c) async {
    final existing = await _cardsByCustomer(customerId: c.id);
    final body = {
      'number':
          c.card.number.isEmpty
              ? 'LC-${c.id.length >= 8 ? c.id.substring(0, 8).toUpperCase() : c.id}'
              : c.card.number,
      'issuedAt': c.card.issuedAt.toUtc().toIso8601String(),
      'points': c.card.points,
      'level': c.card.level,
      'customer': c.id,
      'deleted': false,
    };
    if (existing.containsKey(c.id) && existing[c.id]!.id.isNotEmpty) {
      await _dio.patch('$_cards/${existing[c.id]!.id}', data: body);
    } else {
      await _dio.post(_cards, data: body);
    }
  }

  @override
  Future<Customer> create(Customer customer) async {
    await _auth.ensureLibrarian();
    return guard(() async {
      final r = await _dio.post(
        _path,
        data: {
          'fullName': customer.fullName,
          'email': customer.email,
          'phone': customer.phone,
          'deleted': false,
        },
      );
      // Хук PocketBase создаёт карту лояльности и учётку reader (1 клиент = 1 пользователь).
      final created = _map(Map<String, dynamic>.from(r.data as Map), null);
      if (customer.card.number.isNotEmpty || customer.card.points > 0) {
        await _upsertCard(created.copyWith(card: customer.card));
      }
      return (await findById(created.id)) ?? created;
    });
  }

  @override
  Future<Customer> update(Customer customer) async {
    await _auth.ensureLibrarian();
    return guard(() async {
      await _dio.patch(
        '$_path/${customer.id}',
        data: {
          'fullName': customer.fullName,
          'email': customer.email,
          'phone': customer.phone,
          'deleted': false,
        },
      );
      await _upsertCard(customer);
      return (await findById(customer.id)) ?? customer;
    });
  }

  @override
  Future<void> softDelete(String id) async {
    await _auth.ensureLibrarian();
    await guard(
      () => _dio.patch(
        '$_path/$id',
        data: {
          'deleted': true,
          'deletedAt': DateTime.now().toUtc().toIso8601String(),
        },
      ),
    );
  }

  @override
  Future<void> hardDelete(String id) async {
    await _auth.ensureAdmin();
    await guard(() async {
      final cards = await _cardsByCustomer(customerId: id);
      for (final card in cards.values) {
        if (card.id.isNotEmpty) {
          await _dio.delete('$_cards/${card.id}');
        }
      }
      await _dio.delete('$_path/$id');
    });
  }

  @override
  Future<void> restore(String id) async {
    await _auth.ensureAdmin();
    await guard(
      () =>
          _dio.patch('$_path/$id', data: {'deleted': false, 'deletedAt': null}),
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
    final page = await find(CustomerQuery(search: email.trim(), size: 50));
    final needle = email.trim().toLowerCase();
    return page.items.any(
      (c) =>
          c.email.toLowerCase() == needle &&
          (excludeId == null || excludeId.isEmpty || c.id != excludeId),
    );
  }
}

/// Продажи через кастомный эндпоинт PocketBase (остаток + баллы).
class ApiSalesRepository {
  ApiSalesRepository(this._dio, this._auth);
  final Dio _dio;
  final AuthSession _auth;

  Future<Map<String, dynamic>> createSale({
    required String customerId,
    required List<({String productId, int quantity})> items,
    int pointsToRedeem = 0,
  }) async {
    await _auth.ensureLibrarian();
    return guard(() async {
      final response = await _dio.post(
        '/shop/sales',
        data: {
          'customerId': customerId,
          'pointsToRedeem': pointsToRedeem < 0 ? 0 : pointsToRedeem,
          'items': [
            for (final i in items)
              {'productId': i.productId, 'quantity': i.quantity},
          ],
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    });
  }

  /// Совместимость со старым вызовом одной позиции.
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
    return guardRead(() async {
      final response = await _dio.get(
        '/collections/sales/records',
        queryParameters: {
          'page': 1,
          'perPage': size,
          // У коллекций нет поля created — сортируем по id.
          'sort': '-id',
          'expand': 'customer',
          'filter': 'deleted = false',
        },
      );
      final items = (response.data as Map)['items'] as List? ?? const [];
      final result = <Map<String, dynamic>>[];
      for (final raw in items.whereType<Map>()) {
        result.add(await _mapSale(Map<String, dynamic>.from(raw)));
      }
      return result;
    });
  }

  Future<Map<String, dynamic>> getSale(String id) async {
    await _auth.ensureLoggedIn();
    return guardRead(() async {
      final response = await _dio.get(
        '/collections/sales/records/${Uri.encodeComponent(id)}',
        queryParameters: {'expand': 'customer'},
      );
      return _mapSale(Map<String, dynamic>.from(response.data as Map));
    });
  }

  Future<Map<String, dynamic>> _mapSale(Map<String, dynamic> sale) async {
    final saleId = pbId(sale['id']);
    final itemsRes = await _dio.get(
      '/collections/sale_items/records',
      queryParameters: {
        'page': 1,
        'perPage': 50,
        'filter': 'sale = "$saleId"',
        'expand': 'product',
      },
    );
    final lineItems =
        ((itemsRes.data as Map)['items'] as List? ?? const [])
            .whereType<Map>()
            .map((e) {
              final m = Map<String, dynamic>.from(e);
              final expand =
                  m['expand'] is Map
                      ? Map<String, dynamic>.from(m['expand'] as Map)
                      : const <String, dynamic>{};
              return {
                ...m,
                'product': expand['product'] ?? m['product'],
                'productId': pbId(m['product']),
                'quantity': m['quantity'],
                'unitPrice': m['unitPrice'],
              };
            })
            .toList();
    final expand =
        sale['expand'] is Map
            ? Map<String, dynamic>.from(sale['expand'] as Map)
            : const <String, dynamic>{};
    return {
      'id': saleId,
      'customerId': pbId(sale['customer']),
      'customer': expand['customer'],
      'total': sale['total'],
      'pointsEarned': sale['pointsEarned'],
      'pointsRedeemed': sale['pointsRedeemed'],
      'items': lineItems,
      'product': lineItems.isNotEmpty ? lineItems.first['product'] : null,
      'quantity': lineItems.isNotEmpty ? lineItems.first['quantity'] : null,
    };
  }
}
