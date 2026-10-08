import 'package:flutter_application_1/validation/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Обязательное поле товара', () {
    test('пустая строка отклоняется', () {
      expect(AppValidators.required(''), isNotNull);
      expect(AppValidators.required('   '), isNotNull);
    });

    test('непустая строка принимается', () {
      expect(AppValidators.required('Корм для кошек'), isNull);
    });
  });

  group('Артикул зоотовара', () {
    test('короткий артикул отклоняется', () {
      expect(AppValidators.sku('AB'), isNotNull);
    });

    test('артикул из латиницы и цифр принимается', () {
      expect(AppValidators.sku('PET-1099'), isNull);
    });

    test('кириллица в артикуле отклоняется', () {
      expect(AppValidators.sku('КОРМ-1'), isNotNull);
    });

    test('занятый артикул отклоняется', () {
      expect(
        AppValidators.uniqueSku('PET-1', (sku) => sku == 'PET-1'),
        'Такой артикул уже существует',
      );
    });
  });

  group('Контакты поставщика и клиента', () {
    test('некорректный email отклоняется', () {
      expect(AppValidators.email('не почта'), isNotNull);
    });

    test('короткий телефон отклоняется', () {
      expect(AppValidators.phone('123'), isNotNull);
    });

    test('цена не больше нуля отклоняется', () {
      expect(AppValidators.positiveNumber('0', field: 'Цена'), isNotNull);
      expect(AppValidators.positiveNumber('abc', field: 'Цена'), isNotNull);
    });

    test('рейтинг вне диапазона 1–5 отклоняется', () {
      expect(
        AppValidators.rangeDouble('6', min: 1, max: 5, field: 'Рейтинг'),
        isNotNull,
      );
      expect(
        AppValidators.rangeDouble('4.5', min: 1, max: 5, field: 'Рейтинг'),
        isNull,
      );
    });

    test('отрицательный остаток отклоняется', () {
      expect(AppValidators.nonNegativeInt('-1', field: 'Остаток'), isNotNull);
      expect(AppValidators.nonNegativeInt('0', field: 'Остаток'), isNull);
    });
  });
}
