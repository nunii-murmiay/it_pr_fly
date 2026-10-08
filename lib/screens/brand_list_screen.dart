import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/brand.dart';
import '../models/brand_query.dart';
import '../repositories/product_repository.dart';
import '../state/brand_list_notifier.dart';
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

class BrandListScreen extends StatefulWidget {
  final BrandQuery initialQuery;
  const BrandListScreen({super.key, required this.initialQuery});

  @override
  State<BrandListScreen> createState() => _BrandListScreenState();
}

class _BrandListScreenState extends State<BrandListScreen> {
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BrandListNotifier>().applyQuery(widget.initialQuery);
    });
  }

  @override
  void didUpdateWidget(covariant BrandListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<BrandListNotifier>().applyQuery(widget.initialQuery);
      });
    }
  }

  void _updateUrl(BrandQuery q) {
    final params = <String, String>{};
    if (q.search.isNotEmpty) params['search'] = q.search;
    if (q.sortField != 'name') params['sort'] = q.sortField;
    if (!q.sortAscending) params['asc'] = 'false';
    if (q.page > 1) params['page'] = '${q.page}';
    if (q.size != 10) params['size'] = '${q.size}';
    if (q.includeDeleted) params['includeDeleted'] = 'true';
    context.go(
      Uri(
        path: '/brands',
        queryParameters: params.isEmpty ? null : params,
      ).toString(),
    );
  }

  Future<void> _tryDelete(String id, String name) async {
    final count = await context.read<ProductRepository>().countByBrand(id);
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
                  'Нельзя удалить бренд «$name»: связан с $count товар(ами).',
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
    await context.read<BrandListNotifier>().softDelete(id);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<BrandListNotifier>();
    final narrow = MediaQuery.sizeOf(context).width < Breakpoints.phone;
    return Scaffold(
      appBar: AppBar(title: const Text('Бренды')),
      floatingActionButton: RoleGate(
        operation: AppOperation.manageCatalog,
        child: ResponsiveAddButton(onPressed: () => context.go('/brands/new')),
      ),
      body: Padding(
        padding: EdgeInsets.all(narrow ? 8 : 16),
        child: Column(
          children: [
            ListToolbar(
              search: DebouncedSearchBar(
                initialValue: notifier.query.search,
                hintText: 'Поиск бренда...',
                onChanged:
                    (t) => _updateUrl(notifier.query.copyWith(search: t)),
              ),
              filtersOpen: _showFilters,
              onToggleFilters:
                  () => setState(() => _showFilters = !_showFilters),
              filtersPanel: BrandFilterPanel(
                query: notifier.query,
                onQueryChanged: _updateUrl,
                onReset: () => _updateUrl(const BrandQuery()),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListLoadBody(
                status: notifier.status,
                error: notifier.error,
                isEmpty: notifier.result.items.isEmpty,
                emptyMessage: 'Бренды не найдены',
                onRetry: () => notifier.load(),
                child: AdaptiveEntityBody(
                  cards: [
                    for (final b in notifier.result.items)
                      CatalogItemCard(
                        title: b.name,
                        subtitle: '${b.country}. ${b.description}',
                        selected: notifier.selected.contains(b.id),
                        deleted: b.isDeleted,
                        onToggleSelect: () => notifier.toggleSelection(b.id),
                        actions: EntityActions(
                          deleted: b.isDeleted,
                          onView:
                              () => showRecordDialog(
                                context,
                                title: b.name,
                                rows: [
                                  ('Название', b.name),
                                  ('Страна', b.country),
                                  ('Описание', b.description),
                                ],
                              ),
                          onEdit: () => context.go('/brands/${b.id}/edit'),
                          onDelete: () => _tryDelete(b.id, b.name),
                          onRestore: () => notifier.restore(b.id),
                          onHardDelete: () => notifier.hardDelete(b.id),
                        ),
                      ),
                  ],
                  table: EntityTable<Brand>(
                    items: notifier.result.items,
                    idOf: (b) => b.id,
                    selected: notifier.selected,
                    onToggleSelect: notifier.toggleSelection,
                    onToggleSelectAll:
                        () => notifier.toggleSelectAll(
                          notifier.result.items.map((b) => b.id).toList(),
                        ),
                    sortField: notifier.query.sortField,
                    sortAscending: notifier.query.sortAscending,
                    isDeletedOf: (b) => b.isDeleted,
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
                            (b) => ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 240),
                              child: clipText(b.name),
                            ),
                      ),
                      TableColumnSpec(
                        label: 'Страна',
                        sortField: 'country',
                        build: (b) => clipText(b.country),
                      ),
                      if (!narrow)
                        TableColumnSpec(
                          label: 'Описание',
                          build:
                              (b) => ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 320,
                                ),
                                child: clipText(b.description),
                              ),
                        ),
                    ],
                    actions:
                        (b) => [
                          EntityActions(
                            deleted: b.isDeleted,
                            onView:
                                () => showRecordDialog(
                                  context,
                                  title: b.name,
                                  rows: [
                                    ('Название', b.name),
                                    ('Страна', b.country),
                                    ('Описание', b.description),
                                  ],
                                ),
                            onEdit: () => context.go('/brands/${b.id}/edit'),
                            onDelete: () => _tryDelete(b.id, b.name),
                            onRestore: () => notifier.restore(b.id),
                            onHardDelete: () => notifier.hardDelete(b.id),
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
