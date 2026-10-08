import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';
import '../models/category_query.dart';
import '../models/page_result.dart';
import '../models/seed_data.dart';
import 'category_repository.dart';
import 'prefs_store.dart';

class PersistentCategoryRepository implements CategoryRepository {
  late final PrefsStore<ProductCategory> _store;
  late List<ProductCategory> _items;
  late int _nextId;
  final void Function(String message)? onStorageNotice;

  PersistentCategoryRepository(
    SharedPreferences prefs, {
    this.onStorageNotice,
  }) {
    _store = PrefsStore<ProductCategory>(
      prefs: prefs,
      key: 'categories_v2',
      legacyKey: 'categories_v1',
      fromJson: ProductCategory.fromJson,
      toJson: (c) => c.toJson(),
      seed: seedCategories,
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
  Future<PageResult<ProductCategory>> find(CategoryQuery q) async {
    await Future.delayed(const Duration(milliseconds: 80));
    var rows = _items.where((c) => q.includeDeleted || !c.isDeleted).toList();
    if (q.search.trim().isNotEmpty) {
      final n = q.search.trim().toLowerCase();
      rows =
          rows
              .where(
                (c) =>
                    c.name.toLowerCase().contains(n) ||
                    c.description.toLowerCase().contains(n),
              )
              .toList();
    }
    rows.sort((a, b) {
      final r = a.name.toLowerCase().compareTo(b.name.toLowerCase());
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
  Future<ProductCategory?> findById(String id) async {
    final i = _items.indexWhere((c) => c.id == id);
    return i == -1 ? null : _items[i];
  }

  @override
  Future<List<ProductCategory>> findAll({bool includeDeleted = false}) async {
    return _items.where((c) => includeDeleted || !c.isDeleted).toList();
  }

  @override
  Future<ProductCategory> create(ProductCategory category) async {
    final created = category.copyWith(id: '${_nextId++}');
    _items.add(created);
    await _save();
    return created;
  }

  @override
  Future<ProductCategory> update(ProductCategory category) async {
    final i = _items.indexWhere((c) => c.id == category.id);
    if (i == -1) throw StateError('Категория ${category.id} не найдена');
    _items[i] = category;
    await _save();
    return category;
  }

  @override
  Future<void> softDelete(String id) async {
    final i = _items.indexWhere((c) => c.id == id);
    if (i == -1) throw StateError('Категория $id не найдена');
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
    if (i == -1) throw StateError('Категория $id не найдена');
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
}
