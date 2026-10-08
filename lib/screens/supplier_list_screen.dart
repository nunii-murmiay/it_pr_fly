import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/api_exceptions.dart';
import '../models/supplier.dart';
import '../models/supplier_query.dart';
import '../repositories/product_repository.dart';
import '../state/supplier_list_notifier.dart';
import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../widgets/access_scope.dart';
import '../widgets/adaptive_entity.dart';
import '../widgets/record_dialog.dart';
import '../widgets/entity_table.dart';
import '../widgets/supplier_card.dart';
import '../widgets/list_load_body.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/responsive_chrome.dart';
import '../widgets/search_filter_bar.dart';

class SupplierListScreen extends StatefulWidget {
  final SupplierQuery initialQuery;
  const SupplierListScreen({super.key, required this.initialQuery});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierListNotifier>().applyQuery(widget.initialQuery);
    });
  }

  @override
  void didUpdateWidget(covariant SupplierListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SupplierListNotifier>().applyQuery(widget.initialQuery);
      });
    }
  }

  void _updateUrl(SupplierQuery q) {
    final params = <String, String>{};
    if (q.search.isNotEmpty) params['search'] = q.search;
    if (q.country != null && q.country!.isNotEmpty) {
      params['country'] = q.country!;
    }
    if (q.sortField != 'name') params['sort'] = q.sortField;
    if (!q.sortAscending) params['asc'] = 'false';
    if (q.page > 1) params['page'] = '${q.page}';
    if (q.size != 10) params['size'] = '${q.size}';
    if (q.includeDeleted) params['includeDeleted'] = 'true';
    context.go(
      Uri(
        path: '/suppliers',
        queryParameters: params.isEmpty ? null : params,
      ).toString(),
    );
  }

  Future<void> _tryDelete(String id, String name) async {
    try {
      final count = await context.read<ProductRepository>().countBySupplier(id);
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
                    'Нельзя удалить поставщика «$name»: на него ссылаются $count товар(ов).',
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
      await context.read<SupplierListNotifier>().softDelete(id);
    } on ConflictException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _openSupplier(BuildContext context, Supplier supplier) {
    showRecordDialog(
      context,
      title: supplier.name,
      rows: [
        ('Название', supplier.name),
        ('Страна', supplier.country),
        ('Контакт', supplier.contactPerson),
        ('Телефон', supplier.phone),
        ('Email', supplier.email),
        ('Рейтинг', '${supplier.rating}'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<SupplierListNotifier>();
    final narrow = MediaQuery.sizeOf(context).width < Breakpoints.phone;
    return Scaffold(
      appBar: AppBar(title: const Text('Поставщики')),
      floatingActionButton: RoleGate(
        operation: AppOperation.manageCatalog,
        child: ResponsiveAddButton(
          onPressed: () => context.go('/suppliers/new'),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(narrow ? 8 : 16),
        child: Column(
          children: [
            ListToolbar(
              search: DebouncedSearchBar(
                initialValue: notifier.query.search,
                hintText: 'Поиск поставщика...',
                onChanged:
                    (t) => _updateUrl(notifier.query.copyWith(search: t)),
              ),
              filtersOpen: _showFilters,
              onToggleFilters:
                  () => setState(() => _showFilters = !_showFilters),
              filtersPanel: SupplierFilterPanel(
                query: notifier.query,
                onQueryChanged: _updateUrl,
                onReset: () => _updateUrl(const SupplierQuery()),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListLoadBody(
                status: notifier.status,
                error: notifier.error,
                isEmpty: notifier.result.items.isEmpty,
                emptyMessage: 'Поставщики не найдены',
                onRetry: () => notifier.load(),
                child: AdaptiveEntityBody(
                  cards: [
                    for (final s in notifier.result.items)
                      SupplierCard(
                        supplier: s,
                        isSelected: notifier.selected.contains(s.id),
                        onToggleSelect: notifier.toggleSelection,
                        onView: () => _openSupplier(context, s),
                        onEdit: () => context.go('/suppliers/${s.id}/edit'),
                        onDelete: () => _tryDelete(s.id, s.name),
                        onRestore: () => notifier.restore(s.id),
                        onHardDelete: () => notifier.hardDelete(s.id),
                      ),
                  ],
                  table: EntityTable<Supplier>(
                    items: notifier.result.items,
                    idOf: (s) => s.id,
                    selected: notifier.selected,
                    onToggleSelect: notifier.toggleSelection,
                    onToggleSelectAll:
                        () => notifier.toggleSelectAll(
                          notifier.result.items.map((s) => s.id).toList(),
                        ),
                    sortField: notifier.query.sortField,
                    sortAscending: notifier.query.sortAscending,
                    isDeletedOf: (s) => s.isDeleted,
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
                            (s) => ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: clipText(s.name),
                            ),
                      ),
                      TableColumnSpec(
                        label: 'Страна',
                        sortField: 'country',
                        build: (s) => clipText(s.country),
                      ),
                      if (!narrow) ...[
                        TableColumnSpec(
                          label: 'Контакт',
                          build:
                              (s) => ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 180,
                                ),
                                child: clipText(s.contactPerson),
                              ),
                        ),
                        TableColumnSpec(
                          label: 'Email',
                          build:
                              (s) => ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 200,
                                ),
                                child: clipText(s.email),
                              ),
                        ),
                      ],
                      TableColumnSpec(
                        label: 'Рейтинг',
                        sortField: 'rating',
                        numeric: true,
                        build: (s) => Text('${s.rating}'),
                      ),
                    ],
                    actions:
                        (s) => [
                          EntityActions(
                            deleted: s.isDeleted,
                            onView: () => _openSupplier(context, s),
                            onEdit: () => context.go('/suppliers/${s.id}/edit'),
                            onDelete: () => _tryDelete(s.id, s.name),
                            onRestore: () => notifier.restore(s.id),
                            onHardDelete: () => notifier.hardDelete(s.id),
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
