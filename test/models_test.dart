import 'package:flutter_application_1/models/brand.dart';
import 'package:flutter_application_1/models/customer.dart';
import 'package:flutter_application_1/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Разбор моделей зоомагазина', () {
    test('у товара отсутствующие поля не приводят к исключению', () {
      final product = Product.fromJson({'id': 1});
      expect(product.name, '');
      expect(product.sku, '');
      expect(product.categoryIds, isEmpty);
      expect(product.brandIds, isEmpty);
      expect(product.price, 0);
    });

    test('у бренда пустой json не роняет разбор', () {
      final brand = Brand.fromJson({'id': 3});
      expect(brand.name, '');
      expect(brand.country, '');
      expect(brand.supplierIds, isEmpty);
    });

    test('у клиента без карты поля пустые, а не исключение', () {
      final customer = Customer.fromJson({'id': 2});
      expect(customer.fullName, '');
      expect(customer.email, '');
      expect(customer.card.number, '');
      expect(customer.card.points, 0);
    });
  });
}
