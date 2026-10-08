import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:flutter_application_1/core/api_client.dart';
import 'package:flutter_application_1/core/api_exceptions.dart';
import 'package:flutter_application_1/core/auth_session.dart';
import 'package:flutter_application_1/models/product.dart';
import 'package:flutter_application_1/models/product_query.dart';
import 'package:flutter_application_1/repositories/api_product_repository.dart';

const _records = '/collections/products/records';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late AuthSession auth;
  late ApiProductRepository repo;
  late List<RequestOptions> sent;

  setUp(() {
    auth = AuthSession.fixed('test-token');
    dio = buildDio(tokenProvider: () => auth.accessToken);
    sent = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          sent.add(options);
          handler.next(options);
        },
      ),
    );
    adapter = DioAdapter(
      dio: dio,
      matcher: const UrlRequestMatcher(matchMethod: true),
    );
    repo = ApiProductRepository(dio, auth);
  });

  test('1. find разбирает страницу PocketBase с expand-связями', () async {
    adapter.onGet(
      _records,
      (server) => server.reply(200, {
        'page': 1,
        'perPage': 10,
        'totalItems': 1,
        'totalPages': 1,
        'items': [
          {
            'id': 'abc123',
            'name': 'Корм Premium',
            'sku': 'PET-100',
            'supplier': 'sup2',
            'brands': ['br3'],
            'categories': ['cat4'],
            'price': 1990,
            'stock': 8,
            'rating': 4.7,
            'deleted': false,
            'expand': {
              'supplier': {'id': 'sup2', 'name': 'ЗооОпт'},
              'brands': [
                {'id': 'br3', 'name': 'Royal Canin'},
              ],
              'categories': [
                {'id': 'cat4', 'name': 'Корма'},
              ],
            },
          },
        ],
      }),
    );

    final page = await repo.find(const ProductQuery());
    expect(page.total, 1);
    expect(page.page, 1);
    expect(page.size, 10);
    expect(page.items, hasLength(1));
    final p = page.items.first;
    expect(p.id, 'abc123');
    expect(p.name, 'Корм Premium');
    expect(p.supplierId, 'sup2');
    expect(p.supplierName, 'ЗооОпт');
    expect(p.brandIds, ['br3']);
    expect(p.categoryIds, ['cat4']);
    expect(p.isDeleted, isFalse);
  });

  test('2. find передаёт page, perPage, sort, filter и expand', () async {
    adapter.onGet(
      _records,
      (server) => server.reply(200, {
        'page': 2,
        'perPage': 5,
        'totalItems': 0,
        'items': [],
      }),
    );

    await repo.find(
      const ProductQuery(page: 2, size: 5, search: 'корм', supplierId: 'sup2'),
    );

    expect(sent, hasLength(1));
    expect(sent.first.path, _records);
    final params = sent.first.queryParameters;
    expect(params['page'], 2);
    expect(params['perPage'], 5);
    expect(params['sort'], isA<String>());
    expect(params['expand'], contains('supplier'));
    final filter = params['filter'] as String;
    expect(filter, contains('supplier = "sup2"'));
    expect(filter, contains('корм'));
    expect(filter, contains('deleted = false'));
    expect(sent.first.headers['Authorization'], 'Bearer test-token');
  });

  test(
    '3. create отправляет POST в records и возвращает созданный объект',
    () async {
      adapter.onPost(
        _records,
        (server) => server.reply(200, {
          'id': 'new42',
          'name': 'Игрушка',
          'sku': 'PET-42',
          'supplier': 'sup1',
          'brands': ['br1'],
          'categories': ['cat2'],
          'price': 500,
          'stock': 3,
          'rating': 4.0,
          'deleted': false,
        }),
        data: Matchers.any,
      );

      final created = await repo.create(
        const Product(
          id: '',
          name: 'Игрушка',
          sku: 'PET-42',
          supplierId: 'sup1',
          brandIds: ['br1'],
          categoryIds: ['cat2'],
          price: 500,
          stock: 3,
          rating: 4.0,
        ),
      );
      expect(created.id, 'new42');
      expect(created.sku, 'PET-42');
      expect(created.supplierId, 'sup1');

      final body = sent.single.data as Map;
      expect(body['supplier'], 'sup1');
      expect(body['brands'], ['br1']);
      expect(body['categories'], ['cat2']);
    },
  );

  test(
    '4. ответ 400 PocketBase превращается в ValidationException с ошибками полей',
    () async {
      adapter.onPost(
        _records,
        (server) => server.reply(400, {
          'status': 400,
          'message': 'Ошибка валидации',
          'data': {
            'sku': {
              'code': 'validation_not_unique',
              'message': 'Товар с таким артикулом уже существует',
            },
          },
        }),
        data: Matchers.any,
      );

      expect(
        () => repo.create(
          const Product(
            id: '',
            name: 'Дубликат',
            sku: 'RC-MED-15KG',
            supplierId: 'sup1',
            brandIds: ['br1'],
            categoryIds: ['cat1'],
            price: 100,
            stock: 1,
            rating: 5,
          ),
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.errors['sku'],
            'sku',
            contains('артикул'),
          ),
        ),
      );
    },
  );

  test('5. недоступность сервера даёт NetworkException', () async {
    adapter.onGet(
      _records,
      (server) => server.throws(
        0,
        DioException(
          requestOptions: RequestOptions(path: _records),
          type: DioExceptionType.connectionError,
        ),
      ),
    );

    expect(
      () => repo.find(const ProductQuery()),
      throwsA(isA<NetworkException>()),
    );
  });

  test('6. findById при 404 возвращает null', () async {
    adapter.onGet(
      '$_records/missing',
      (server) => server.reply(404, {'message': 'Не найдено'}),
    );

    final found = await repo.findById('missing');
    expect(found, isNull);
  });

  test('7. softDelete отправляет PATCH с deleted: true', () async {
    adapter.onPatch(
      '$_records/rec7',
      (server) => server.reply(200, {'id': 'rec7', 'deleted': true}),
      data: Matchers.any,
    );

    await repo.softDelete('rec7');

    final body = sent.single.data as Map;
    expect(body['deleted'], isTrue);
    expect(sent.single.method, 'PATCH');
  });

  test('8. ответ 409 даёт ConflictException со строковым productId', () async {
    adapter.onDelete(
      '$_records/rec9',
      (server) => server.reply(409, {
        'message': 'Есть связанные товары',
        'productId': 'rec5',
      }),
    );

    expect(
      () => repo.hardDelete('rec9'),
      throwsA(
        isA<ConflictException>().having(
          (e) => e.productId,
          'productId',
          'rec5',
        ),
      ),
    );
  });
}
