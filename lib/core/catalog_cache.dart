import '../models/brand.dart';
import '../models/category.dart';
import '../models/supplier.dart';
import '../repositories/brand_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/supplier_repository.dart';
import '../models/brand_query.dart';
import '../models/category_query.dart';
import '../models/supplier_query.dart';

/// Кэш справочников: один запрос на сессию (п.15 задания).
class CatalogCache {
  CatalogCache({
    required BrandRepository brands,
    required CategoryRepository categories,
    required SupplierRepository suppliers,
  }) : _brands = brands,
       _categories = categories,
       _suppliers = suppliers;

  final BrandRepository _brands;
  final CategoryRepository _categories;
  final SupplierRepository _suppliers;

  List<Brand>? _brandList;
  List<ProductCategory>? _categoryList;
  List<Supplier>? _supplierList;

  Future<List<Brand>> brands({bool force = false}) async {
    if (_brandList == null || force) {
      final page = await _brands.find(const BrandQuery(size: 100));
      _brandList = page.items;
    }
    return _brandList!;
  }

  Future<List<ProductCategory>> categories({bool force = false}) async {
    if (_categoryList == null || force) {
      final page = await _categories.find(const CategoryQuery(size: 100));
      _categoryList = page.items;
    }
    return _categoryList!;
  }

  Future<List<Supplier>> suppliers({bool force = false}) async {
    if (_supplierList == null || force) {
      final page = await _suppliers.find(const SupplierQuery(size: 100));
      _supplierList = page.items;
    }
    return _supplierList!;
  }

  void invalidate() {
    _brandList = null;
    _categoryList = null;
    _supplierList = null;
  }
}
