import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer.dart';
import '../models/customer_query.dart';
import '../models/page_result.dart';
import '../models/seed_data.dart';
import 'customer_repository.dart';
import 'prefs_store.dart';

class PersistentCustomerRepository implements CustomerRepository {
  late final PrefsStore<Customer> _store;
  late List<Customer> _items;
  late int _nextId;
  final void Function(String message)? onStorageNotice;

  PersistentCustomerRepository(
    SharedPreferences prefs, {
    this.onStorageNotice,
  }) {
    _store = PrefsStore<Customer>(
      prefs: prefs,
      key: 'customers_v2',
      legacyKey: 'customers_v1',
      fromJson: Customer.fromJson,
      toJson: (c) => c.toJson(),
      seed: seedCustomers,
      onMigrated: onStorageNotice,
    );
    _items = _store.restore();
    _nextId =
        _items.fold<int>(0, (m, e) {
          final n = int.tryParse(e.id) ?? 0;
          return n > m ? n : m;
        }) +
        1;
  }

  Future<void> _save() => _store.persist(_items);

  @override
  Future<PageResult<Customer>> find(CustomerQuery q) async {
    await Future.delayed(const Duration(milliseconds: 100));
    var rows = _items.where((c) => q.includeDeleted || !c.isDeleted).toList();
    if (q.search.trim().isNotEmpty) {
      final n = q.search.trim().toLowerCase();
      rows =
          rows
              .where(
                (c) =>
                    c.fullName.toLowerCase().contains(n) ||
                    c.email.toLowerCase().contains(n) ||
                    c.phone.toLowerCase().contains(n) ||
                    c.card.number.toLowerCase().contains(n),
              )
              .toList();
    }
    if (q.cardLevel != null && q.cardLevel!.isNotEmpty) {
      rows = rows.where((c) => c.card.level == q.cardLevel).toList();
    }
    rows.sort((a, b) {
      final r = switch (q.sortField) {
        'email' => a.email.toLowerCase().compareTo(b.email.toLowerCase()),
        'points' => a.card.points.compareTo(b.card.points),
        'level' => a.card.level.compareTo(b.card.level),
        _ => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      };
      return q.sortAscending ? r : -r;
    });
    final total = rows.length;
    final from = (q.page - 1) * q.size;
    final to = (from + q.size) > total ? total : from + q.size;
    return PageResult(
      items: from >= total ? [] : rows.sublist(from, to),
      page: q.page,
      size: q.size,
      total: total,
    );
  }

  @override
  Future<Customer?> findById(String id) async {
    final i = _items.indexWhere((c) => c.id == id);
    return i == -1 ? null : _items[i];
  }

  @override
  Future<List<Customer>> findAll({bool includeDeleted = false}) async {
    return _items.where((c) => includeDeleted || !c.isDeleted).toList();
  }

  @override
  Future<Customer> create(Customer customer) async {
    final created = customer.copyWith(id: '${_nextId++}');
    _items.add(created);
    await _save();
    return created;
  }

  @override
  Future<Customer> update(Customer customer) async {
    final i = _items.indexWhere((c) => c.id == customer.id);
    if (i == -1) throw StateError('Клиент ${customer.id} не найден');
    _items[i] = customer;
    await _save();
    return customer;
  }

  @override
  Future<void> softDelete(String id) async {
    final i = _items.indexWhere((c) => c.id == id);
    if (i == -1) throw StateError('Клиент $id не найден');
    _items[i] = _items[i].copyWith(deletedAt: DateTime.now());
    await _save();
  }

  @override
  Future<void> hardDelete(String id) async {
    _items.removeWhere((c) => c.id == id);
    await _save();
  }

  @override
  Future<void> restore(String id) async {
    final i = _items.indexWhere((c) => c.id == id);
    if (i == -1) throw StateError('Клиент $id не найден');
    _items[i] = _items[i].copyWith(clearDeletedAt: true);
    await _save();
  }

  @override
  Future<int> deleteMany(List<String> ids) async {
    var c = 0;
    for (final id in ids) {
      final i = _items.indexWhere((x) => x.id == id && !x.isDeleted);
      if (i != -1) {
        _items[i] = _items[i].copyWith(deletedAt: DateTime.now());
        c++;
      }
    }
    await _save();
    return c;
  }

  @override
  Future<int> restoreMany(List<String> ids) async {
    var c = 0;
    for (final id in ids) {
      final i = _items.indexWhere((x) => x.id == id && x.isDeleted);
      if (i != -1) {
        _items[i] = _items[i].copyWith(clearDeletedAt: true);
        c++;
      }
    }
    await _save();
    return c;
  }

  @override
  Future<bool> isEmailTaken(String email, {String? excludeId}) async {
    final needle = email.trim().toLowerCase();
    return _items.any(
      (c) =>
          !c.isDeleted &&
          c.email.toLowerCase() == needle &&
          (excludeId == null || c.id != excludeId),
    );
  }
}
