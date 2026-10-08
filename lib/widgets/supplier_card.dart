import 'package:flutter/material.dart';
import '../models/supplier.dart';
import 'adaptive_entity.dart';

class SupplierCard extends StatelessWidget {
  final Supplier supplier;
  final bool isSelected;
  final ValueChanged<String>? onToggleSelect;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onHardDelete;

  const SupplierCard({
    super.key,
    required this.supplier,
    this.isSelected = false,
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
          supplier.isDeleted
              ? theme.colorScheme.errorContainer.withValues(alpha: 0.15)
              : (isSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
                  : null),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (onToggleSelect != null) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onToggleSelect!(supplier.id),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      clipText(
                        supplier.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration:
                              supplier.isDeleted
                                  ? TextDecoration.lineThrough
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: clipText(
                              supplier.country,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber.shade900),
                      const SizedBox(width: 4),
                      Text(
                        '${supplier.rating}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _contactRow(
                  Icons.person_outline,
                  supplier.contactPerson,
                  theme,
                ),
                const SizedBox(height: 4),
                _contactRow(Icons.phone_outlined, supplier.phone, theme),
                const SizedBox(height: 4),
                _contactRow(Icons.email_outlined, supplier.email, theme),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: EntityActions(
                deleted: supplier.isDeleted,
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

  Widget _contactRow(IconData icon, String text, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: clipText(
            text,
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}
