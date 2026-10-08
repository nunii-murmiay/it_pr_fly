import 'package:flutter/material.dart';

import '../core/breakpoints.dart';
import '../core/permissions.dart';
import 'access_scope.dart';

/// На узком экране — круглая кнопка «+», на широком — «+ Добавить».
class ResponsiveAddButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const ResponsiveAddButton({
    super.key,
    required this.onPressed,
    this.label = 'Добавить',
  });

  static const double compactBreakpoint = Breakpoints.phone;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < compactBreakpoint;
    if (compact) {
      return RoleGate(
        operation: AppOperation.manageCatalog,
        child: FloatingActionButton(
          onPressed: onPressed,
          tooltip: label,
          child: const Icon(Icons.add),
        ),
      );
    }
    return RoleGate(
      operation: AppOperation.manageCatalog,
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        icon: const Icon(Icons.add),
        label: Text(label),
      ),
    );
  }
}

/// Поиск + фильтры: на мобильном фильтр — иконка, элементы не вылезают.
class ListToolbar extends StatelessWidget {
  final Widget search;
  final VoidCallback onToggleFilters;
  final bool filtersOpen;
  final Widget? filtersPanel;

  const ListToolbar({
    super.key,
    required this.search,
    required this.onToggleFilters,
    required this.filtersOpen,
    this.filtersPanel,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < Breakpoints.phone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 8),
            if (narrow)
              IconButton.outlined(
                onPressed: onToggleFilters,
                tooltip: filtersOpen ? 'Скрыть фильтры' : 'Фильтры',
                icon: Icon(
                  filtersOpen ? Icons.filter_list_off : Icons.filter_list,
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: onToggleFilters,
                icon: Icon(filtersOpen ? Icons.expand_less : Icons.expand_more),
                label: Text(filtersOpen ? 'Скрыть' : 'Фильтры'),
              ),
          ],
        ),
        if (filtersOpen && filtersPanel != null) ...[
          const SizedBox(height: 8),
          filtersPanel!,
        ],
      ],
    );
  }
}
