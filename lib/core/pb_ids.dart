/// PocketBase использует строковые id. Пустая строка — новая несохранённая запись.
String pbId(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is Map) {
    final id = value['id'];
    if (id != null) return id.toString();
  }
  return value.toString();
}

List<String> pbIdList(dynamic value) {
  if (value is! List) {
    if (value == null || value == '') return const [];
    return [pbId(value)];
  }
  return value.map(pbId).where((id) => id.isNotEmpty).toList();
}

DateTime? pbDate(dynamic value) {
  if (value == null || value == '') return null;
  return DateTime.tryParse(value.toString());
}

bool pbDeleted(Map<String, dynamic> json) {
  if (json['deleted'] == true) return true;
  return json['deletedAt'] != null && '${json['deletedAt']}'.isNotEmpty;
}
