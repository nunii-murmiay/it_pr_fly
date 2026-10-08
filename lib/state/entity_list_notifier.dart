import 'package:flutter/foundation.dart';
import '../models/page_result.dart';

enum LoadStatus { idle, loading, success, error }

/// Базовый нотификатор списка с выбором и CRUD-действиями.
abstract class EntityListNotifier<T, Q> extends ChangeNotifier {
  PageResult<T> _result = PageResult.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<String> _selected = {};
  late Q _query;

  EntityListNotifier(Q initialQuery) {
    _query = initialQuery;
  }

  Q get query => _query;
  PageResult<T> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<String> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  Future<PageResult<T>> fetch(Q query);
  String idOf(T item);
  Future<void> doSoftDelete(String id);
  Future<void> doHardDelete(String id);
  Future<void> doRestore(String id);
  Future<void> doDeleteMany(List<String> ids);
  Future<void> doRestoreMany(List<String> ids);

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _result = await fetch(_query);
      _status = LoadStatus.success;
    } catch (e) {
      // Отменённый устаревший поиск не должен портить UI.
      final text = e.toString();
      if (text.contains('отменён') ||
          text.contains('CancelledException') ||
          text.contains('cancel')) {
        return;
      }
      _error = text;
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> applyQuery(Q next) async {
    _query = next;
    _selected.clear();
    await load();
  }

  void toggleSelection(String id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    notifyListeners();
  }

  void toggleSelectAll(List<String> visibleIds) {
    final allSelected = visibleIds.every(_selected.contains);
    if (allSelected) {
      for (final id in visibleIds) {
        _selected.remove(id);
      }
    } else {
      _selected.addAll(visibleIds);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selected.clear();
    notifyListeners();
  }

  Future<void> softDelete(String id) async {
    await doSoftDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<void> hardDelete(String id) async {
    await doHardDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<void> restore(String id) async {
    await doRestore(id);
    await load();
  }

  Future<void> deleteSelected() async {
    if (_selected.isEmpty) return;
    await doDeleteMany(_selected.toList());
    _selected.clear();
    await load();
  }

  Future<void> restoreSelected() async {
    if (_selected.isEmpty) return;
    await doRestoreMany(_selected.toList());
    _selected.clear();
    await load();
  }

  void simulateError() {
    _status = LoadStatus.error;
    _error = 'Ошибка загрузки (имитация для проверки UI)';
    notifyListeners();
  }
}
