import 'package:flutter/material.dart';

import '../core/breakpoints.dart';
import '../core/permissions.dart';
import 'access_scope.dart';

Widget clipText(String text, {TextStyle? style, int maxLines = 1}) {
  return Text(
    text,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: style,
  );
}

/// Таблица на широком окне, карточки — на узком.
/// Одна колонка ниже 768, две колонки от 768 до 1279.
class AdaptiveEntityBody extends StatelessWidget {
  final Widget table;
  final List<Widget> cards;

  const AdaptiveEntityBody({
    super.key,
    required this.table,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    final window = MediaQuery.sizeOf(context).width;
    if (window >= Breakpoints.desktop) return table;

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns =
            window >= Breakpoints.phone && constraints.maxWidth >= 520;
        if (!twoColumns) {
          return ListView(children: cards);
        }

        final rows = <Widget>[];
        for (var i = 0; i < cards.length; i += 2) {
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[i]),
                const SizedBox(width: 12),
                Expanded(
                  child:
                      i + 1 < cards.length
                          ? cards[i + 1]
                          : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        }
        return ListView(children: rows);
      },
    );
  }
}

class CatalogItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool deleted;
  final VoidCallback? onToggleSelect;
  final Widget? actions;

  const CatalogItemCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.selected = false,
    this.deleted = false,
    this.onToggleSelect,
    this.actions,
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
            selected
                ? BorderSide(color: theme.colorScheme.primary, width: 2)
                : BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
      ),
      color:
          deleted
              ? theme.colorScheme.errorContainer.withValues(alpha: 0.15)
              : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (onToggleSelect != null)
                  Checkbox(
                    value: selected,
                    onChanged: (_) => onToggleSelect!(),
                  ),
                Expanded(
                  child: clipText(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: deleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
            clipText(
              subtitle,
              maxLines: 2,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (actions != null) ...[
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: actions!),
            ],
          ],
        ),
      ),
    );
  }
}

class EntityActions extends StatelessWidget {
  final bool deleted;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onHardDelete;

  const EntityActions({
    super.key,
    required this.deleted,
    this.onView,
    this.onEdit,
    this.onDelete,
    this.onRestore,
    this.onHardDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onView != null)
          IconButton(
            tooltip: 'Просмотр карточки',
            icon: const Icon(Icons.visibility_outlined, size: 18),
            onPressed: onView,
          ),
        if (!deleted && onEdit != null)
          RoleGate(
            operation: AppOperation.manageCatalog,
            child: IconButton(
              tooltip: 'Редактировать',
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: onEdit,
            ),
          ),
        if (!deleted && onDelete != null)
          RoleGate(
            operation: AppOperation.manageCatalog,
            child: IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: onDelete,
            ),
          ),
        if (deleted && onRestore != null)
          RoleGate(
            operation: AppOperation.restoreDeleted,
            child: IconButton(
              tooltip: 'Восстановить',
              icon: const Icon(Icons.restore, size: 18),
              onPressed: onRestore,
            ),
          ),
        if (deleted && onHardDelete != null)
          RoleGate(
            operation: AppOperation.hardDelete,
            child: IconButton(
              tooltip: 'Удалить навсегда',
              color: Colors.red,
              icon: const Icon(Icons.delete_forever, size: 18),
              onPressed: onHardDelete,
            ),
          ),
      ],
    );
  }
}
