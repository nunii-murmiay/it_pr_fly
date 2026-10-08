import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exceptions.dart';
import '../core/auth_session.dart';
import '../core/pb_query.dart';
import '../models/page_result.dart';
import '../models/supplier.dart';
import '../models/supplier_query.dart';
import 'supplier_repository.dart';

class ApiSupplierRepository implements SupplierRepository {
  ApiSupplierRepository(this._dio, this._auth);
  final Dio _dio;
  final AuthSession _auth;
  CancelToken? _findToken;

  static const _path = '/collections/suppliers/records';

  @override
  Future<PageResult<Supplier>> find(SupplierQuery q) async {
    await _auth.ensureLoggedIn();
    _findToken?.cancel('устаревший поиск');
    _findToken = CancelToken();
    final token = _findToken!;
    final parts =
        <String>[
          if (q.search.trim().isNotEmpty)
            pbSearchFilter(q.search, const [
              'name',
              'country',
              'contactPerson',
              'email',
            ]),
          if (q.country != null && q.country!.isNotEmpty)
            'country = "${pbEscape(q.country!)}"',
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
                .map(
                  (e) => Supplier.fromJson(
                    pbRecordToApp(Map<String, dynamic>.from(e)),
                  ),
                )
                .toList(),
        page: (mapped['page'] as num).toInt(),
        size: (mapped['size'] as num).toInt(),
        total: (mapped['total'] as num).toInt(),
      );
    });
  }

  @override
  Future<Supplier?> findById(String id) async {
    await _auth.ensureLoggedIn();
    try {
      return await guardRead(() async {
        final r = await _dio.get('$_path/$id');
        return Supplier.fromJson(
          pbRecordToApp(Map<String, dynamic>.from(r.data as Map)),
        );
      });
    } on NotFoundException {
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

  Map<String, dynamic> _body(Supplier s) => {
    'name': s.name,
    'country': s.country,
    'contactPerson': s.contactPerson,
    'phone': s.phone,
    'email': s.email,
    'rating': s.rating,
    'deleted': false,
  };

  @override
  Future<Supplier> create(Supplier supplier) async {
    await _auth.ensureLibrarian();
    return guard(() async {
      final r = await _dio.post(_path, data: _body(supplier));
      return Supplier.fromJson(
        pbRecordToApp(Map<String, dynamic>.from(r.data as Map)),
      );
    });
  }

  @override
  Future<Supplier> update(Supplier supplier) async {
    await _auth.ensureLibrarian();
    return guard(() async {
      final r = await _dio.patch(
        '$_path/${supplier.id}',
        data: _body(supplier),
      );
      return Supplier.fromJson(
        pbRecordToApp(Map<String, dynamic>.from(r.data as Map)),
      );
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
