import 'package:shared_preferences/shared_preferences.dart';
import '../models/page_result.dart';
import '../models/seed_data.dart';
import '../models/supplier.dart';
import '../models/supplier_query.dart';
import 'prefs_store.dart';
import 'supplier_repository.dart';

class PersistentSupplierRepository implements SupplierRepository {
  late final PrefsStore<Supplier> _store;
  late List<Supplier> _items;
  late int _nextId;
  final void Function(String message)? onStorageNotice;

  PersistentSupplierRepository(
    SharedPreferences prefs, {
    this.onStorageNotice,
  }) {
    _store = PrefsStore<Supplier>(
      prefs: prefs,
      key: 'suppliers_v2',
      legacyKey: 'suppliers_v1',
      fromJson: Supplier.fromJson,
      toJson: (s) => s.toJson(),
      seed: seedSuppliers,
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
  Future<PageResult<Supplier>> find(SupplierQuery q) async {
    await Future.delayed(const Duration(milliseconds: 100));
    var rows = _items.where((s) => q.includeDeleted || !s.isDeleted).toList();
    if (q.search.trim().isNotEmpty) {
      final n = q.search.trim().toLowerCase();
      rows =
          rows
              .where(
                (s) =>
                    s.name.toLowerCase().contains(n) ||
                    s.country.toLowerCase().contains(n) ||
                    s.contactPerson.toLowerCase().contains(n) ||
                    s.email.toLowerCase().contains(n),
              )
              .toList();
    }
    if (q.country != null && q.country!.isNotEmpty) {
      rows =
          rows
              .where((s) => s.country.toLowerCase() == q.country!.toLowerCase())
              .toList();
    }
    rows.sort((a, b) {
      final r = switch (q.sortField) {
        'country' => a.country.toLowerCase().compareTo(b.country.toLowerCase()),
        'rating' => a.rating.compareTo(b.rating),
        'contactPerson' => a.contactPerson.toLowerCase().compareTo(
          b.contactPerson.toLowerCase(),
        ),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
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
  Future<Supplier?> findById(String id) async {
    final i = _items.indexWhere((s) => s.id == id);
    return i == -1 ? null : _items[i];
  }

  @override
  Future<List<Supplier>> findAll({bool includeDeleted = false}) async {
    return _items.where((s) => includeDeleted || !s.isDeleted).toList();
  }

  @override
  Future<Supplier> create(Supplier supplier) async {
    final created = supplier.copyWith(id: '${_nextId++}');
    _items.add(created);
    await _save();
    return created;
  }

  @override
  Future<Supplier> update(Supplier supplier) async {
    final i = _items.indexWhere((s) => s.id == supplier.id);
    if (i == -1) throw StateError('Поставщик ${supplier.id} не найден');
    _items[i] = supplier;
    await _save();
    return supplier;
  }

  @override
  Future<void> softDelete(String id) async {
    final i = _items.indexWhere((s) => s.id == id);
    if (i == -1) throw StateError('Поставщик $id не найден');
    _items[i] = _items[i].copyWith(deletedAt: DateTime.now());
    await _save();
  }

  @override
  Future<void> hardDelete(String id) async {
    _items.removeWhere((s) => s.id == id);
    await _save();
  }

  @override
  Future<void> restore(String id) async {
    final i = _items.indexWhere((s) => s.id == id);
    if (i == -1) throw StateError('Поставщик $id не найден');
    _items[i] = _items[i].copyWith(clearDeletedAt: true);
    await _save();
  }

  @override
  Future<int> deleteMany(List<String> ids) async {
    var c = 0;
    for (final id in ids) {
      final i = _items.indexWhere((s) => s.id == id && !s.isDeleted);
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
      final i = _items.indexWhere((s) => s.id == id && s.isDeleted);
      if (i != -1) {
        _items[i] = _items[i].copyWith(clearDeletedAt: true);
        c++;
      }
    }
    await _save();
    return c;
  }
}
