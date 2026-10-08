import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../models/category_query.dart';
import '../repositories/product_repository.dart';
import '../state/category_list_notifier.dart';
import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../widgets/access_scope.dart';
import '../widgets/adaptive_entity.dart';
import '../widgets/record_dialog.dart';
import '../widgets/entity_table.dart';
import '../widgets/list_load_body.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/responsive_chrome.dart';
import '../widgets/search_filter_bar.dart';

class CategoryListScreen extends StatefulWidget {
  final CategoryQuery initialQuery;
  const CategoryListScreen({super.key, required this.initialQuery});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryListNotifier>().applyQuery(widget.initialQuery);
    });
  }

  @override
  void didUpdateWidget(covariant CategoryListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CategoryListNotifier>().applyQuery(widget.initialQuery);
      });
    }
  }

  void _updateUrl(CategoryQuery q) {
    final params = <String, String>{};
    if (q.search.isNotEmpty) params['search'] = q.search;
    if (q.page > 1) params['page'] = '${q.page}';
    if (q.size != 10) params['size'] = '${q.size}';
    if (q.includeDeleted) params['includeDeleted'] = 'true';
    context.go(
      Uri(
        path: '/categories',
        queryParameters: params.isEmpty ? null : params,
      ).toString(),
    );
  }

  Future<void> _tryDelete(String id, String name) async {
    final count = await context.read<ProductRepository>().countByCategory(id);
    if (!mounted) return;
    if (count > 0) {
      await showDialog<void>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Удаление невозможно'),
              content: ConstrainedBox(
                constraints: Breakpoints.dialogConstraints,
                child: Text(
                  'Нельзя удалить категорию «$name»: связана с $count товар(ами).',
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Понятно'),
                ),
              ],
            ),
      );
      return;
    }
    await context.read<CategoryListNotifier>().softDelete(id);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<CategoryListNotifier>();
    final narrow = MediaQuery.sizeOf(context).width < Breakpoints.phone;
    return Scaffold(
      appBar: AppBar(title: const Text('Категории')),
      floatingActionButton: RoleGate(
        operation: AppOperation.manageCatalog,
        child: ResponsiveAddButton(
          onPressed: () => context.go('/categories/new'),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(narrow ? 8 : 16),
        child: Column(
          children: [
            ListToolbar(
              search: DebouncedSearchBar(
                initialValue: notifier.query.search,
                hintText: 'Поиск категории...',
                onChanged:
                    (t) => _updateUrl(notifier.query.copyWith(search: t)),
              ),
              filtersOpen: _showFilters,
              onToggleFilters:
                  () => setState(() => _showFilters = !_showFilters),
              filtersPanel: CategoryFilterPanel(
                query: notifier.query,
                onQueryChanged: _updateUrl,
                onReset: () => _updateUrl(const CategoryQuery()),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListLoadBody(
                status: notifier.status,
                error: notifier.error,
                isEmpty: notifier.result.items.isEmpty,
                emptyMessage: 'Категории не найдены',
                onRetry: () => notifier.load(),
                child: AdaptiveEntityBody(
                  cards: [
                    for (final c in notifier.result.items)
                      CatalogItemCard(
                        title: c.name,
                        subtitle: c.description,
                        selected: notifier.selected.contains(c.id),
                        deleted: c.isDeleted,
                        onToggleSelect: () => notifier.toggleSelection(c.id),
                        actions: EntityActions(
                          deleted: c.isDeleted,
                          onView:
                              () => showRecordDialog(
                                context,
                                title: c.name,
                                rows: [
                                  ('Название', c.name),
                                  ('Описание', c.description),
                                  ('Иконка', c.iconName),
                                ],
                              ),
                          onEdit: () => context.go('/categories/${c.id}/edit'),
                          onDelete: () => _tryDelete(c.id, c.name),
                          onRestore: () => notifier.restore(c.id),
                          onHardDelete: () => notifier.hardDelete(c.id),
                        ),
                      ),
                  ],
                  table: EntityTable<ProductCategory>(
                    items: notifier.result.items,
                    idOf: (c) => c.id,
                    selected: notifier.selected,
                    onToggleSelect: notifier.toggleSelection,
                    onToggleSelectAll:
                        () => notifier.toggleSelectAll(
                          notifier.result.items.map((c) => c.id).toList(),
                        ),
                    sortField: notifier.query.sortField,
                    sortAscending: notifier.query.sortAscending,
                    isDeletedOf: (c) => c.isDeleted,
                    onSort:
                        (f) => _updateUrl(
                          notifier.query.copyWith(
                            sortField: f,
                            sortAscending:
                                f == notifier.query.sortField
                                    ? !notifier.query.sortAscending
                                    : true,
                          ),
                        ),
                    columns: [
                      TableColumnSpec(
                        label: 'Название',
                        sortField: 'name',
                        build:
                            (c) => ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 240),
                              child: clipText(c.name),
                            ),
                      ),
                      TableColumnSpec(
                        label: 'Описание',
                        build:
                            (c) => ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: clipText(c.description),
                            ),
                      ),
                      if (!narrow)
                        TableColumnSpec(
                          label: 'Иконка',
                          build: (c) => clipText(c.iconName),
                        ),
                    ],
                    actions:
                        (c) => [
                          EntityActions(
                            deleted: c.isDeleted,
                            onView:
                                () => showRecordDialog(
                                  context,
                                  title: c.name,
                                  rows: [
                                    ('Название', c.name),
                                    ('Описание', c.description),
                                    ('Иконка', c.iconName),
                                  ],
                                ),
                            onEdit:
                                () => context.go('/categories/${c.id}/edit'),
                            onDelete: () => _tryDelete(c.id, c.name),
                            onRestore: () => notifier.restore(c.id),
                            onHardDelete: () => notifier.hardDelete(c.id),
                          ),
                        ],
                  ),
                ),
              ),
            ),
            PaginationBar(
              page: notifier.result.page,
              size: notifier.result.size,
              totalPages: notifier.result.totalPages,
              totalItems: notifier.result.total,
              hasPrevious: notifier.result.hasPrevious,
              hasNext: notifier.result.hasNext,
              onPageChanged:
                  (p) => _updateUrl(notifier.query.copyWith(page: p)),
              onSizeChanged:
                  (s) => _updateUrl(notifier.query.copyWith(size: s, page: 1)),
            ),
          ],
        ),
      ),
    );
  }
}
