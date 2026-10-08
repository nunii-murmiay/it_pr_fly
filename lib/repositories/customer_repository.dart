import '../models/customer.dart';
import '../models/customer_query.dart';
import '../models/page_result.dart';

abstract interface class CustomerRepository {
  Future<PageResult<Customer>> find(CustomerQuery query);
  Future<Customer?> findById(String id);
  Future<List<Customer>> findAll({bool includeDeleted = false});
  Future<Customer> create(Customer customer);
  Future<Customer> update(Customer customer);
  Future<void> softDelete(String id);
  Future<void> hardDelete(String id);
  Future<void> restore(String id);
  Future<int> deleteMany(List<String> ids);
  Future<int> restoreMany(List<String> ids);
  Future<bool> isEmailTaken(String email, {String? excludeId});
}
