import '../models/brand.dart';
import '../models/brand_query.dart';
import '../models/page_result.dart';

abstract interface class BrandRepository {
  Future<PageResult<Brand>> find(BrandQuery query);
  Future<Brand?> findById(String id);
  Future<List<Brand>> findAll({bool includeDeleted = false});
  Future<Brand> create(Brand brand);
  Future<Brand> update(Brand brand);
  Future<void> softDelete(String id);
  Future<void> hardDelete(String id);
  Future<void> restore(String id);
  Future<int> deleteMany(List<String> ids);
  Future<int> restoreMany(List<String> ids);
}
