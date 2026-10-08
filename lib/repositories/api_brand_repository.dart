import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exceptions.dart';
import '../core/auth_session.dart';
import '../core/pb_query.dart';
import '../models/brand.dart';
import '../models/brand_query.dart';
import '../models/page_result.dart';
import 'brand_repository.dart';

class ApiBrandRepository implements BrandRepository {
  ApiBrandRepository(this._dio, this._auth);
  final Dio _dio;
  final AuthSession _auth;
  CancelToken? _findToken;

  static const _path = '/collections/brands/records';

  Brand _map(Map<String, dynamic> raw) =>
      Brand.fromJson(pbRecordToApp(Map<String, dynamic>.from(raw)));

  @override
  Future<PageResult<Brand>> find(BrandQuery q) async {
    await _auth.ensureLoggedIn();
    _findToken?.cancel('устаревший поиск');
    _findToken = CancelToken();
    final token = _findToken!;
    final parts =
        <String>[
          if (q.search.trim().isNotEmpty)
            pbSearchFilter(q.search, const ['name', 'country', 'description']),
          if (q.country != null && q.country!.isNotEmpty)
            'country = "${pbEscape(q.country!)}"',
          if (q.supplierId != null && q.supplierId!.isNotEmpty)
            pbRelationContains('suppliers', q.supplierId),
        ].where((e) => e.isNotEmpty).toList();

    return guardRead(() async {
      final response = await _dio.get(
        _path,
        queryParameters:
            PbListQuery(
              page: q.page,
              perPage: q.size,
              sort: pbSort(q.sortField, q.sortAscending),
              filterParts: parts,
              expand: 'suppliers',
              includeDeleted: q.includeDeleted,
            ).toParams(),
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
  Future<Brand?> findById(String id) async {
    await _auth.ensureLoggedIn();
    try {
      return await guardRead(() async {
        final r = await _dio.get(
          '$_path/$id',
          queryParameters: {'expand': 'suppliers'},
        );
        return _map(Map<String, dynamic>.from(r.data as Map));
      });
    } on NotFoundException {
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

  Map<String, dynamic> _body(Brand b) => {
    'name': b.name,
    'country': b.country,
    'description': b.description,
    'suppliers': b.supplierIds,
    'deleted': false,
  };

  @override
  Future<Brand> create(Brand brand) async {
    await _auth.ensureLibrarian();
    return guard(() async {
      final r = await _dio.post(
        _path,
        data: _body(brand),
        queryParameters: {'expand': 'suppliers'},
      );
      return _map(Map<String, dynamic>.from(r.data as Map));
    });
  }

  @override
  Future<Brand> update(Brand brand) async {
    await _auth.ensureLibrarian();
    return guard(() async {
      final r = await _dio.patch(
        '$_path/${brand.id}',
        data: _body(brand),
        queryParameters: {'expand': 'suppliers'},
      );
      return _map(Map<String, dynamic>.from(r.data as Map));
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
}
