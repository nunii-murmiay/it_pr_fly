import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/catalog_cache.dart';
import 'package:flutter_application_1/models/brand.dart';
import 'package:flutter_application_1/models/brand_query.dart';
import 'package:flutter_application_1/models/category.dart';
import 'package:flutter_application_1/models/category_query.dart';
import 'package:flutter_application_1/models/page_result.dart';
import 'package:flutter_application_1/models/product.dart';
import 'package:flutter_application_1/models/product_query.dart';
import 'package:flutter_application_1/models/role.dart';
import 'package:flutter_application_1/models/supplier.dart';
import 'package:flutter_application_1/models/supplier_query.dart';
import 'package:flutter_application_1/repositories/brand_repository.dart';
import 'package:flutter_application_1/repositories/category_repository.dart';
import 'package:flutter_application_1/repositories/product_repository.dart';
import 'package:flutter_application_1/repositories/supplier_repository.dart';
import 'package:flutter_application_1/screens/product_form_screen.dart';
import 'package:flutter_application_1/state/entity_list_notifier.dart';
import 'package:flutter_application_1/widgets/access_scope.dart';
import 'package:flutter_application_1/widgets/adaptive_entity.dart';
import 'package:flutter_application_1/widgets/list_load_body.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('список показывает индикатор загрузки', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ListLoadBody(
            status: LoadStatus.loading,
            error: null,
            isEmpty: false,
            emptyMessage: 'Товары не найдены',
            onRetry: _noop,
            child: Text('данные'),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('данные'), findsNothing);
  });

  testWidgets('список показывает сообщение при пустом результате', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ListLoadBody(
            status: LoadStatus.success,
            error: null,
            isEmpty: true,
            emptyMessage: 'Товары не найдены',
            onRetry: _noop,
            child: Text('данные'),
          ),
        ),
      ),
    );

    expect(find.text('Товары не найдены'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ошибка связи показывает текст и кнопку повтора', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListLoadBody(
            status: LoadStatus.error,
            error: 'Сервер недоступен. Проверьте соединение.',
            isEmpty: true,
            emptyMessage: 'Товары не найдены',
            onRetry: () => retried = true,
            child: const Text('данные'),
          ),
        ),
      ),
    );

    expect(find.textContaining('Сервер недоступен'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Повторить'));
    expect(retried, isTrue);
  });

  testWidgets('форма товара не сохраняется с пустым названием', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProductRepository>(create: (_) => _FakeProducts()),
          Provider<CatalogCache>(
            create:
                (_) => CatalogCache(
                  brands: _FakeBrands(),
                  categories: _FakeCategories(),
                  suppliers: _FakeSuppliers(),
                ),
          ),
        ],
        child: const MaterialApp(home: ProductFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final save = find.text('Создать');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump();

    expect(find.text('Название обязательно для заполнения'), findsOneWidget);
  });

  testWidgets('покупатель не видит удаление навсегда', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AccessScope(
          role: Role.reader,
          child: Scaffold(
            body: EntityActions(
              deleted: true,
              onHardDelete: _noop,
              onRestore: _noop,
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Удалить навсегда'), findsNothing);
    expect(find.byTooltip('Восстановить'), findsNothing);
  });

  testWidgets('администратор видит удаление навсегда', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AccessScope(
          role: Role.admin,
          child: Scaffold(
            body: EntityActions(
              deleted: true,
              onHardDelete: _noop,
              onRestore: _noop,
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Удалить навсегда'), findsOneWidget);
  });
}

void _noop() {}

class _FakeProducts implements ProductRepository {
  @override
  Future<Product> create(Product product) => throw UnimplementedError();

  @override
  Future<int> countByBrand(
    String brandId, {
    bool includeDeleted = false,
  }) async => 0;

  @override
  Future<int> countByCategory(
    String categoryId, {
    bool includeDeleted = false,
  }) async => 0;

  @override
  Future<int> countBySupplier(
    String supplierId, {
    bool includeDeleted = false,
  }) async => 0;

  @override
  Future<int> deleteMany(List<String> ids) async => 0;

  @override
  Future<PageResult<Product>> find(ProductQuery query) async =>
      PageResult.empty();

  @override
  Future<List<Product>> findAll({bool includeDeleted = false}) async => [];

  @override
  Future<Product?> findById(String id) async => null;

  @override
  Future<void> hardDelete(String id) async {}

  @override
  Future<bool> isSkuTaken(String sku, {String? excludeId}) async => false;

  @override
  Future<void> restore(String id) async {}

  @override
  Future<int> restoreMany(List<String> ids) async => 0;

  @override
  Future<void> softDelete(String id) async {}

  @override
  Future<Product> update(Product product) => throw UnimplementedError();
}

class _FakeBrands implements BrandRepository {
  @override
  Future<Brand> create(Brand brand) => throw UnimplementedError();

  @override
  Future<int> deleteMany(List<String> ids) async => 0;

  @override
  Future<PageResult<Brand>> find(BrandQuery query) async => PageResult.empty();

  @override
  Future<List<Brand>> findAll({bool includeDeleted = false}) async => [];

  @override
  Future<Brand?> findById(String id) async => null;

  @override
  Future<void> hardDelete(String id) async {}

  @override
  Future<void> restore(String id) async {}

  @override
  Future<int> restoreMany(List<String> ids) async => 0;

  @override
  Future<void> softDelete(String id) async {}

  @override
  Future<Brand> update(Brand brand) => throw UnimplementedError();
}

class _FakeCategories implements CategoryRepository {
  @override
  Future<ProductCategory> create(ProductCategory category) =>
      throw UnimplementedError();

  @override
  Future<int> deleteMany(List<String> ids) async => 0;

  @override
  Future<PageResult<ProductCategory>> find(CategoryQuery query) async =>
      PageResult.empty();

  @override
  Future<List<ProductCategory>> findAll({bool includeDeleted = false}) async =>
      [];

  @override
  Future<ProductCategory?> findById(String id) async => null;

  @override
  Future<void> hardDelete(String id) async {}

  @override
  Future<void> restore(String id) async {}

  @override
  Future<int> restoreMany(List<String> ids) async => 0;

  @override
  Future<void> softDelete(String id) async {}

  @override
  Future<ProductCategory> update(ProductCategory category) =>
      throw UnimplementedError();
}

class _FakeSuppliers implements SupplierRepository {
  @override
  Future<Supplier> create(Supplier supplier) => throw UnimplementedError();

  @override
  Future<int> deleteMany(List<String> ids) async => 0;

  @override
  Future<PageResult<Supplier>> find(SupplierQuery query) async =>
      PageResult.empty();

  @override
  Future<List<Supplier>> findAll({bool includeDeleted = false}) async => [];

  @override
  Future<Supplier?> findById(String id) async => null;

  @override
  Future<void> hardDelete(String id) async {}

  @override
  Future<void> restore(String id) async {}

  @override
  Future<int> restoreMany(List<String> ids) async => 0;

  @override
  Future<void> softDelete(String id) async {}

  @override
  Future<Supplier> update(Supplier supplier) => throw UnimplementedError();
}
