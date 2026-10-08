import '../models/page_result.dart';
import '../models/supplier.dart';
import '../models/supplier_query.dart';

abstract interface class SupplierRepository {
  Future<PageResult<Supplier>> find(SupplierQuery query);
  Future<Supplier?> findById(String id);
  Future<List<Supplier>> findAll({bool includeDeleted = false});
  Future<Supplier> create(Supplier supplier);
  Future<Supplier> update(Supplier supplier);
  Future<void> softDelete(String id);
  Future<void> hardDelete(String id);
  Future<void> restore(String id);
  Future<int> deleteMany(List<String> ids);
  Future<int> restoreMany(List<String> ids);
}
