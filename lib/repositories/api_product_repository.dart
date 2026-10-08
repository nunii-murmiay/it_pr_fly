import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exceptions.dart';
import '../core/auth_session.dart';
import '../core/pb_query.dart';
import '../models/page_result.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import 'product_repository.dart';

class ApiProductRepository implements ProductRepository {
  ApiProductRepository(this._dio, this._auth);

  final Dio _dio;
  final AuthSession _auth;
  CancelToken? _findToken;

  static const _path = '/collections/products/records';
  static const _expand = 'supplier,brands,categories';

  Product _map(Map<String, dynamic> raw) =>
      Product.fromJson(pbRecordToApp(Map<String, dynamic>.from(raw)));

  Map<String, dynamic> _write(Product p) => {
    'name': p.name,
    'sku': p.sku,
    'supplier': p.supplierId,
    'categories': p.categoryIds,
    'brands': p.brandIds,
    'price': p.price,
    'stock': p.stock,
    'rating': p.rating,
    'deleted': false,
  };

  PbListQuery _q(ProductQuery q) {
    final parts =
        <String>[
          if (q.search.trim().isNotEmpty)
            pbSearchFilter(q.search, const ['name', 'sku']),
          if (q.supplierId != null && q.supplierId!.isNotEmpty)
            pbRelationEquals('supplier', q.supplierId),
          if (q.brandId != null && q.brandId!.isNotEmpty)
            pbRelationContains('brands', q.brandId),
          if (q.categoryId != null && q.categoryId!.isNotEmpty)
            pbRelationContains('categories', q.categoryId),
          if (q.priceFrom != null) 'price >= ${q.priceFrom}',
          if (q.priceTo != null) 'price <= ${q.priceTo}',
        ].where((e) => e.isNotEmpty).toList();

    return PbListQuery(
      page: q.page,
      perPage: q.size,
      sort: pbSort(q.sortField, q.sortAscending),
      filterParts: parts,
      expand: _expand,
      includeDeleted: q.includeDeleted,
    );
  }

  @override
  Future<PageResult<Product>> find(ProductQuery q) async {
    await _auth.ensureLoggedIn();
    _findToken?.cancel('устаревший поиск');
    _findToken = CancelToken();
    final token = _findToken!;

    return guardRead(() async {
      final response = await _dio.get(
        _path,
        queryParameters: _q(q).toParams(),
        cancelToken: token,
      );
      final mapped = pbPageResult(
        Map<String, dynamic>.from(response.data as Map),
      );
      return PageResult(
        items:
            (mapped['items'] as List)
                .whereType<Map>()
                .map((e) => _map(Map<String, dynamic>.from(e)))
                .toList(),
        page: (mapped['page'] as num).toInt(),
        size: (mapped['size'] as num).toInt(),
        total: (mapped['total'] as num).toInt(),
      );
    });
  }

  @override
  Future<Product?> findById(String id) async {
    await _auth.ensureLoggedIn();
    try {
      return await guardRead(() async {
        final response = await _dio.get(
          '$_path/$id',
          queryParameters: {'expand': _expand},
        );
        return _map(Map<String, dynamic>.from(response.data as Map));
      });
    } on NotFoundException {
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
    return guard(() async {
      final response = await _dio.post(
        _path,
        data: _write(product),
        queryParameters: {'expand': _expand},
      );
      return _map(Map<String, dynamic>.from(response.data as Map));
    });
  }

  @override
  Future<Product> update(Product product) async {
    await _auth.ensureLibrarian();
    return guard(() async {
      final response = await _dio.patch(
        '$_path/${product.id}',
        data: _write(product),
        queryParameters: {'expand': _expand},
      );
      return _map(Map<String, dynamic>.from(response.data as Map));
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
    await guard(() => _dio.delete('$_path/$id'));
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
  Future<bool> isSkuTaken(String sku, {String? excludeId}) async {
    final page = await find(ProductQuery(search: sku.trim(), size: 50));
    final needle = sku.trim().toUpperCase();
    return page.items.any(
      (p) =>
          p.sku.toUpperCase() == needle &&
          (excludeId == null || excludeId.isEmpty || p.id != excludeId),
    );
  }

  @override
  Future<int> countBySupplier(
    String supplierId, {
    bool includeDeleted = false,
  }) async {
    final page = await find(
      ProductQuery(
        supplierId: supplierId,
        size: 1,
        includeDeleted: includeDeleted,
      ),
    );
    return page.total;
  }

  @override
  Future<int> countByBrand(
    String brandId, {
    bool includeDeleted = false,
  }) async {
    final page = await find(
      ProductQuery(brandId: brandId, size: 1, includeDeleted: includeDeleted),
    );
    return page.total;
  }

  @override
  Future<int> countByCategory(
    String categoryId, {
    bool includeDeleted = false,
  }) async {
    final page = await find(
      ProductQuery(
        categoryId: categoryId,
        size: 1,
        includeDeleted: includeDeleted,
      ),
    );
    return page.total;
  }
}
