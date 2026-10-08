import 'package:flutter/material.dart';
import '../models/product.dart';
import 'adaptive_entity.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final String supplierName;
  final bool isSelected;
  final bool showSku;
  final ValueChanged<String>? onToggleSelect;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onHardDelete;

  const ProductCard({
    super.key,
    required this.product,
    required this.supplierName,
    this.isSelected = false,
    this.showSku = true,
    this.onToggleSelect,
    this.onView,
    this.onEdit,
    this.onDelete,
    this.onRestore,
    this.onHardDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            isSelected
                ? BorderSide(color: theme.colorScheme.primary, width: 2)
                : BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
      ),
      color:
          product.isDeleted
              ? theme.colorScheme.errorContainer.withValues(alpha: 0.15)
              : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onToggleSelect?.call(product.id),
                ),
                Expanded(
                  child: clipText(
                    product.name,
                    maxLines: 2,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration:
                          product.isDeleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Text(
                  '${product.price.toStringAsFixed(0)} ₽',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            clipText(
              showSku
                  ? 'Артикул: ${product.sku} · $supplierName'
                  : supplierName,
            ),
            Text('Склад: ${product.stock} шт. · ★ ${product.rating}'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: EntityActions(
                deleted: product.isDeleted,
                onView: onView,
                onEdit: onEdit,
                onDelete: onDelete,
                onRestore: onRestore,
                onHardDelete: onHardDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
