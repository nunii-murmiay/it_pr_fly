import 'package:flutter_application_1/core/supabase_map.dart';
import 'package:flutter_application_1/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapProductRow', () {
    test('собирает бренды и категории из junction-строк', () {
      final mapped = mapProductRow({
        'id': '44444444-4444-4444-4444-444444444401',
        'name': 'RC Adult Dog 3 кг',
        'sku': 'RC-DOG-3',
        'supplier_id': '11111111-1111-1111-1111-111111111101',
        'price': 2890,
        'stock': 25,
        'rating': 4.9,
        'deleted': false,
        'suppliers': {
          'id': '11111111-1111-1111-1111-111111111101',
          'name': 'Royal Canin RU',
        },
        'product_brands': [
          {
            'brand_id': '33333333-3333-3333-3333-333333333301',
            'brands': {
              'id': '33333333-3333-3333-3333-333333333301',
              'name': 'Royal Canin',
            },
          },
        ],
        'product_categories': [
          {
            'category_id': '22222222-2222-2222-2222-222222222201',
            'categories': {
              'id': '22222222-2222-2222-2222-222222222201',
              'name': 'Корма',
            },
          },
        ],
      });
      final product = Product.fromJson(mapped);
      expect(product.name, 'RC Adult Dog 3 кг');
      expect(
        product.brandIds,
        contains('33333333-3333-3333-3333-333333333301'),
      );
      expect(product.categoryNames, contains('Корма'));
      expect(product.supplierName, 'Royal Canin RU');
    });
  });
}
