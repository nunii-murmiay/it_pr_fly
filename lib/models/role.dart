/// Роли учебного API (имена совпадают с сервером).
enum Role {
  reader(1, 'reader', 'Покупатель'),
  librarian(2, 'librarian', 'Менеджер'),
  admin(3, 'admin', 'Администратор');

  const Role(this.level, this.apiName, this.label);

  final int level;
  final String apiName;
  final String label;

  static Role fromApi(String? value) {
    final v = (value ?? '').toLowerCase().trim();
    return Role.values.firstWhere(
      (r) => r.apiName == v,
      orElse: () => Role.reader,
    );
  }

  bool atLeast(Role other) => level >= other.level;
}
