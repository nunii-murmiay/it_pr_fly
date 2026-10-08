import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Универсальное хранилище списка сущностей в localStorage (web).
class PrefsStore<T> {
  final SharedPreferences prefs;
  final String key;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;
  final List<T> seed;
  final String? legacyKey;
  final void Function(String message)? onMigrated;

  PrefsStore({
    required this.prefs,
    required this.key,
    required this.fromJson,
    required this.toJson,
    required this.seed,
    this.legacyKey,
    this.onMigrated,
  });

  List<T> restore() {
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        return list
            .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        prefs.remove(key);
        onMigrated?.call(
          'Формат данных устарел или повреждён ($key). Загружен начальный набор.',
        );
      }
    }

    if (legacyKey != null) {
      final legacy = prefs.getString(legacyKey!);
      if (legacy != null) {
        try {
          final list = jsonDecode(legacy) as List;
          final items =
              list
                  .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
                  .toList();
          persist(items);
          prefs.remove(legacyKey!);
          onMigrated?.call(
            'Данные перенесены на новый формат хранилища ($key).',
          );
          return items;
        } catch (_) {
          prefs.remove(legacyKey!);
          onMigrated?.call(
            'Старые данные повреждены. Загружен начальный набор ($key).',
          );
        }
      }
    }

    final initial = [...seed];
    persist(initial);
    return initial;
  }

  Future<void> persist(List<T> items) async {
    await prefs.setString(key, jsonEncode(items.map(toJson).toList()));
  }
}
