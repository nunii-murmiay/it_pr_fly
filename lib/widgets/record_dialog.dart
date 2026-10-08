import 'package:flutter/material.dart';

import '../models/product.dart';

Future<void> showRecordDialog(
  BuildContext context, {
  required String title,
  required List<(String, String)> rows,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.pets, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final row in rows) _row(row.$1, row.$2)],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      );
    },
  );
}

Future<void> showProductViewDialog(
  BuildContext context, {
  required Product product,
  required String supplierName,
  required String categoriesLabel,
}) {
  return showRecordDialog(
    context,
    title: product.name,
    rows: [
      ('Артикул', product.sku),
      ('Цена', '${product.price.toStringAsFixed(0)} ₽'),
      ('Количество', '${product.stock} шт.'),
      ('Категории', categoriesLabel),
      ('Поставщик', product.supplierName ?? supplierName),
      ('Рейтинг', '★ ${product.rating}'),
    ],
  );
}

Widget _row(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value.isEmpty ? '—' : value)),
      ],
    ),
  );
}
