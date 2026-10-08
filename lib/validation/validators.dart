/// Общие валидаторы форм зоомагазина.
class AppValidators {
  AppValidators._();

  static String? required(String? value, {String field = 'Поле'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field обязательно для заполнения';
    }
    return null;
  }

  static String? minLength(String? value, int min, {String field = 'Поле'}) {
    final base = required(value, field: field);
    if (base != null) return base;
    if (value!.trim().length < min) {
      return '$field: минимум $min символов';
    }
    return null;
  }

  static String? maxLength(String? value, int max, {String field = 'Поле'}) {
    if (value != null && value.trim().length > max) {
      return '$field: максимум $max символов';
    }
    return null;
  }

  static String? lengthRange(
    String? value, {
    required int min,
    required int max,
    String field = 'Поле',
  }) {
    return minLength(value, min, field: field) ??
        maxLength(value, max, field: field);
  }

  static String? positiveNumber(String? value, {String field = 'Число'}) {
    final base = required(value, field: field);
    if (base != null) return base;
    final n = num.tryParse(value!.trim().replaceAll(',', '.'));
    if (n == null) return '$field должно быть числом';
    if (n <= 0) return '$field должно быть больше нуля';
    return null;
  }

  static String? nonNegativeInt(String? value, {String field = 'Количество'}) {
    final base = required(value, field: field);
    if (base != null) return base;
    final n = int.tryParse(value!.trim());
    if (n == null) return '$field должно быть целым числом';
    if (n < 0) return '$field не может быть отрицательным';
    return null;
  }

  static String? rangeDouble(
    String? value, {
    required double min,
    required double max,
    String field = 'Значение',
  }) {
    final base = required(value, field: field);
    if (base != null) return base;
    final n = double.tryParse(value!.trim().replaceAll(',', '.'));
    if (n == null) return '$field должно быть числом';
    if (n < min || n > max) {
      return '$field должно быть от $min до $max';
    }
    return null;
  }

  static String? email(String? value, {String field = 'Email'}) {
    final base = required(value, field: field);
    if (base != null) return base;
    final email = value!.trim();
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!re.hasMatch(email)) return 'Некорректный формат email';
    return null;
  }

  static String? phone(String? value, {String field = 'Телефон'}) {
    final base = required(value, field: field);
    if (base != null) return base;
    final digits = value!.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return '$field: укажите не менее 10 цифр';
    return null;
  }

  static String? sku(String? value) {
    final base = lengthRange(value, min: 4, max: 32, field: 'Артикул');
    if (base != null) return base;
    final sku = value!.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9\-]+$').hasMatch(sku)) {
      return 'Артикул: только латиница, цифры и дефис';
    }
    return null;
  }

  static String? uniqueSku(String? value, bool Function(String sku) exists) {
    final base = sku(value);
    if (base != null) return base;
    if (exists(value!.trim())) {
      return 'Такой артикул уже существует';
    }
    return null;
  }

  static String? uniqueEmail(
    String? value,
    bool Function(String email) exists,
  ) {
    final base = email(value);
    if (base != null) return base;
    if (exists(value!.trim())) {
      return 'Этот email уже зарегистрирован';
    }
    return null;
  }

  static String? requiredId(String? value, {String field = 'Значение'}) {
    if (value == null || value.trim().isEmpty) return 'Выберите $field';
    return null;
  }

  static String? nonEmptyIds(List<String>? value, {String field = 'элемент'}) {
    if (value == null || value.isEmpty) {
      return 'Выберите хотя бы один $field';
    }
    return null;
  }
}
