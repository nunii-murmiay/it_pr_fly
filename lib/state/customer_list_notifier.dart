import '../models/customer.dart';
import '../models/customer_query.dart';
import '../models/page_result.dart';
import '../repositories/customer_repository.dart';
import 'entity_list_notifier.dart';

class CustomerListNotifier extends EntityListNotifier<Customer, CustomerQuery> {
  final CustomerRepository _repository;

  CustomerListNotifier(this._repository) : super(const CustomerQuery());

  @override
  Future<PageResult<Customer>> fetch(CustomerQuery query) =>
      _repository.find(query);

  @override
  String idOf(Customer item) => item.id;

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
