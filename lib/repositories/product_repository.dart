import '../models/page_result.dart';
import '../models/product.dart';
import '../models/product_query.dart';

abstract interface class ProductRepository {
  Future<PageResult<Product>> find(ProductQuery query);
  Future<Product?> findById(String id);
  Future<List<Product>> findAll({bool includeDeleted = false});
  Future<Product> create(Product product);
  Future<Product> update(Product product);
  Future<void> softDelete(String id);
  Future<void> hardDelete(String id);
  Future<void> restore(String id);
  Future<int> deleteMany(List<String> ids);
  Future<int> restoreMany(List<String> ids);
  Future<bool> isSkuTaken(String sku, {String? excludeId});
  Future<int> countBySupplier(String supplierId, {bool includeDeleted = false});
  Future<int> countByBrand(String brandId, {bool includeDeleted = false});
  Future<int> countByCategory(String categoryId, {bool includeDeleted = false});
}
