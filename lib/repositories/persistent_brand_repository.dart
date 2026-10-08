import 'package:shared_preferences/shared_preferences.dart';
import '../models/brand.dart';
import '../models/brand_query.dart';
import '../models/page_result.dart';
import '../models/seed_data.dart';
import 'brand_repository.dart';
import 'prefs_store.dart';

class PersistentBrandRepository implements BrandRepository {
  late final PrefsStore<Brand> _store;
  late List<Brand> _items;
  late int _nextId;
  final void Function(String message)? onStorageNotice;

  PersistentBrandRepository(SharedPreferences prefs, {this.onStorageNotice}) {
    _store = PrefsStore<Brand>(
      prefs: prefs,
      key: 'brands_v2',
      legacyKey: 'brands_v1',
      fromJson: Brand.fromJson,
      toJson: (b) => b.toJson(),
      seed: seedBrands,
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
  Future<PageResult<Brand>> find(BrandQuery q) async {
    await Future.delayed(const Duration(milliseconds: 100));
    var rows = _items.where((b) => q.includeDeleted || !b.isDeleted).toList();
    if (q.search.trim().isNotEmpty) {
      final n = q.search.trim().toLowerCase();
      rows =
          rows
              .where(
                (b) =>
                    b.name.toLowerCase().contains(n) ||
                    b.country.toLowerCase().contains(n) ||
                    b.description.toLowerCase().contains(n),
              )
              .toList();
    }
    if (q.country != null && q.country!.isNotEmpty) {
      rows =
          rows
              .where((b) => b.country.toLowerCase() == q.country!.toLowerCase())
              .toList();
    }
    if (q.supplierId != null) {
      rows = rows.where((b) => b.supplierIds.contains(q.supplierId)).toList();
    }
    rows.sort((a, b) {
      final r = switch (q.sortField) {
        'country' => a.country.toLowerCase().compareTo(b.country.toLowerCase()),
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
  Future<Brand?> findById(String id) async {
    final i = _items.indexWhere((b) => b.id == id);
    return i == -1 ? null : _items[i];
  }

  @override
  Future<List<Brand>> findAll({bool includeDeleted = false}) async {
    return _items.where((b) => includeDeleted || !b.isDeleted).toList();
  }

  @override
  Future<Brand> create(Brand brand) async {
    final created = brand.copyWith(id: '${_nextId++}');
    _items.add(created);
    await _save();
    return created;
  }

  @override
  Future<Brand> update(Brand brand) async {
    final i = _items.indexWhere((b) => b.id == brand.id);
    if (i == -1) throw StateError('Бренд ${brand.id} не найден');
    _items[i] = brand;
    await _save();
    return brand;
  }

  @override
  Future<void> softDelete(String id) async {
    final i = _items.indexWhere((b) => b.id == id);
    if (i == -1) throw StateError('Бренд $id не найден');
    _items[i] = _items[i].copyWith(deletedAt: DateTime.now());
    await _save();
  }

  @override
  Future<void> hardDelete(String id) async {
    _items.removeWhere((b) => b.id == id);
    await _save();
  }

  @override
  Future<void> restore(String id) async {
    final i = _items.indexWhere((b) => b.id == id);
    if (i == -1) throw StateError('Бренд $id не найден');
    _items[i] = _items[i].copyWith(clearDeletedAt: true);
    await _save();
  }

  @override
  Future<int> deleteMany(List<String> ids) async {
    var c = 0;
    for (final id in ids) {
      final i = _items.indexWhere((b) => b.id == id && !b.isDeleted);
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
      final i = _items.indexWhere((b) => b.id == id && b.isDeleted);
      if (i != -1) {
        _items[i] = _items[i].copyWith(clearDeletedAt: true);
        c++;
      }
    }
    await _save();
    return c;
  }
}
