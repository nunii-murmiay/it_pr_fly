import '../models/category.dart';
import '../models/category_query.dart';
import '../models/page_result.dart';

abstract interface class CategoryRepository {
  Future<PageResult<ProductCategory>> find(CategoryQuery query);
  Future<ProductCategory?> findById(String id);
  Future<List<ProductCategory>> findAll({bool includeDeleted = false});
  Future<ProductCategory> create(ProductCategory category);
  Future<ProductCategory> update(ProductCategory category);
  Future<void> softDelete(String id);
  Future<void> hardDelete(String id);
  Future<void> restore(String id);
  Future<int> deleteMany(List<String> ids);
  Future<int> restoreMany(List<String> ids);
}
