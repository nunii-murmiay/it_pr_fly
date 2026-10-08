import '../models/page_result.dart';
import '../models/supplier.dart';
import '../models/supplier_query.dart';
import '../repositories/supplier_repository.dart';
import 'entity_list_notifier.dart';

export 'entity_list_notifier.dart' show LoadStatus;

class SupplierListNotifier extends EntityListNotifier<Supplier, SupplierQuery> {
  final SupplierRepository _repository;

  SupplierListNotifier(this._repository) : super(const SupplierQuery());

  @override
  Future<PageResult<Supplier>> fetch(SupplierQuery query) =>
      _repository.find(query);

  @override
  String idOf(Supplier item) => item.id;

  @override
  Future<void> doSoftDelete(String id) => _repository.softDelete(id);

  @override
  Future<void> doHardDelete(String id) => _repository.hardDelete(id);

  @override
  Future<void> doRestore(String id) => _repository.restore(id);

  @override
  Future<void> doDeleteMany(List<String> ids) => _repository.deleteMany(ids);

  @override
  Future<void> doRestoreMany(List<String> ids) => _repository.restoreMany(ids);
}
