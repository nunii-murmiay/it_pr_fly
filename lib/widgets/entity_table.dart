import 'package:flutter/material.dart';

class TableColumnSpec<T> {
  final String label;
  final String? sortField;
  final bool numeric;
  final Widget Function(T item) build;
  final double? width;

  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
    this.width,
  });
}

class EntityTable<T> extends StatelessWidget {
  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final String Function(T item) idOf;
  final Set<String> selected;
  final ValueChanged<String>? onToggleSelect;
  final VoidCallback? onToggleSelectAll;
  final String? sortField;
  final bool sortAscending;
  final void Function(String field)? onSort;
  final List<Widget> Function(T item)? actions;
  final bool Function(T item)? isDeletedOf;

  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    this.selected = const {},
    this.onToggleSelect,
    this.onToggleSelectAll,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.actions,
    this.isDeletedOf,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleIds = items.map(idOf).toList();
    final allSelected =
        visibleIds.isNotEmpty && visibleIds.every(selected.contains);
    final someSelected = visibleIds.any(selected.contains) && !allSelected;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 700;
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  dataRowMinHeight: narrow ? 44 : 52,
                  dataRowMaxHeight: narrow ? 56 : 64,
                  horizontalMargin: narrow ? 8 : 16,
                  columnSpacing: narrow ? 12 : 24,
                  showCheckboxColumn: false,
                  columns: [
                    if (onToggleSelect != null)
                      DataColumn(
                        label: Checkbox(
                          value:
                              allSelected
                                  ? true
                                  : (someSelected ? null : false),
                          tristate: true,
                          onChanged: (_) => onToggleSelectAll?.call(),
                        ),
                      ),
                    ...columns.map((col) {
                      final isCurrentSort =
                          col.sortField != null && col.sortField == sortField;
                      return DataColumn(
                        numeric: col.numeric,
                        onSort:
                            col.sortField != null && onSort != null
                                ? (_, __) => onSort!(col.sortField!)
                                : null,
                        label: InkWell(
                          onTap:
                              col.sortField != null && onSort != null
                                  ? () => onSort!(col.sortField!)
                                  : null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                col.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isCurrentSort
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface,
                                ),
                              ),
                              if (col.sortField != null) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  isCurrentSort
                                      ? (sortAscending
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward)
                                      : Icons.unfold_more,
                                  size: 16,
                                  color:
                                      isCurrentSort
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.outline
                                              .withValues(alpha: 0.5),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                    if (actions != null)
                      DataColumn(
                        label: Text(
                          narrow ? '' : 'Действия',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                  rows:
                      items.map((item) {
                        final id = idOf(item);
                        final isSelected = selected.contains(id);
                        final isDeleted = isDeletedOf?.call(item) ?? false;

                        return DataRow(
                          selected: isSelected,
                          color: WidgetStateProperty.resolveWith((states) {
                            if (isSelected) {
                              return theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.3);
                            }
                            if (isDeleted) {
                              return theme.colorScheme.errorContainer
                                  .withValues(alpha: 0.15);
                            }
                            if (states.contains(WidgetState.hovered)) {
                              return theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.2);
                            }
                            return null;
                          }),
                          cells: [
                            if (onToggleSelect != null)
                              DataCell(
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => onToggleSelect!(id),
                                ),
                              ),
                            ...columns.map((col) {
                              return DataCell(
                                Opacity(
                                  opacity: isDeleted ? 0.6 : 1.0,
                                  child: col.build(item),
                                ),
                              );
                            }),
                            if (actions != null)
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: actions!(item),
                                ),
                              ),
                          ],
                        );
                      }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
