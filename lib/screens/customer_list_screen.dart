import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../models/customer_query.dart';
import '../state/customer_list_notifier.dart';
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

class CustomerListScreen extends StatefulWidget {
  final CustomerQuery initialQuery;
  const CustomerListScreen({super.key, required this.initialQuery});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerListNotifier>().applyQuery(widget.initialQuery);
    });
  }

  @override
  void didUpdateWidget(covariant CustomerListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CustomerListNotifier>().applyQuery(widget.initialQuery);
      });
    }
  }

  void _updateUrl(CustomerQuery q) {
    final params = <String, String>{};
    if (q.search.isNotEmpty) params['search'] = q.search;
    if (q.cardLevel != null) params['level'] = q.cardLevel!;
    if (q.sortField != 'fullName') params['sort'] = q.sortField;
    if (!q.sortAscending) params['asc'] = 'false';
    if (q.page > 1) params['page'] = '${q.page}';
    if (q.size != 10) params['size'] = '${q.size}';
    if (q.includeDeleted) params['includeDeleted'] = 'true';
    context.go(
      Uri(
        path: '/customers',
        queryParameters: params.isEmpty ? null : params,
      ).toString(),
    );
  }

  void _openCustomer(BuildContext context, Customer customer) {
    showRecordDialog(
      context,
      title: customer.fullName,
      rows: [
        ('ФИО', customer.fullName),
        ('Email', customer.email),
        ('Телефон', customer.phone),
        ('Карта', customer.card.number),
        ('Уровень', customer.card.level),
        ('Баллы', '${customer.card.points}'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<CustomerListNotifier>();
    final narrow = MediaQuery.sizeOf(context).width < Breakpoints.phone;
    return Scaffold(
      appBar: AppBar(title: const Text('Клиенты')),
      floatingActionButton: RoleGate(
        operation: AppOperation.manageCustomers,
        child: ResponsiveAddButton(
          onPressed: () => context.go('/customers/new'),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(narrow ? 8 : 16),
        child: Column(
          children: [
            ListToolbar(
              search: DebouncedSearchBar(
                initialValue: notifier.query.search,
                hintText: 'Поиск клиента...',
                onChanged:
                    (t) => _updateUrl(notifier.query.copyWith(search: t)),
              ),
              filtersOpen: _showFilters,
              onToggleFilters:
                  () => setState(() => _showFilters = !_showFilters),
              filtersPanel: CustomerFilterPanel(
                query: notifier.query,
                onQueryChanged: _updateUrl,
                onReset: () => _updateUrl(const CustomerQuery()),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListLoadBody(
                status: notifier.status,
                error: notifier.error,
                isEmpty: notifier.result.items.isEmpty,
                emptyMessage: 'Клиенты не найдены',
                onRetry: () => notifier.load(),
                child: AdaptiveEntityBody(
                  cards: [
                    for (final c in notifier.result.items)
                      CatalogItemCard(
                        title: c.fullName,
                        subtitle: '${c.email} · ${c.phone} · ${c.card.level}',
                        selected: notifier.selected.contains(c.id),
                        deleted: c.isDeleted,
                        onToggleSelect: () => notifier.toggleSelection(c.id),
                        actions: EntityActions(
                          deleted: c.isDeleted,
                          onView: () => _openCustomer(context, c),
                          onEdit: () => context.go('/customers/${c.id}/edit'),
                          onDelete: () => notifier.softDelete(c.id),
                          onRestore: () => notifier.restore(c.id),
                          onHardDelete: () => notifier.hardDelete(c.id),
                        ),
                      ),
                  ],
                  table: EntityTable<Customer>(
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
                        label: 'ФИО',
                        sortField: 'fullName',
                        build:
                            (c) => ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: clipText(c.fullName),
                            ),
                      ),
                      TableColumnSpec(
                        label: 'Email',
                        sortField: 'email',
                        build:
                            (c) => ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: clipText(c.email),
                            ),
                      ),
                      TableColumnSpec(
                        label: 'Телефон',
                        build: (c) => clipText(c.phone),
                      ),
                      if (!narrow) ...[
                        TableColumnSpec(
                          label: 'Карта',
                          build: (c) => Text(c.card.number),
                        ),
                        TableColumnSpec(
                          label: 'Уровень',
                          sortField: 'level',
                          build: (c) => Text(c.card.level),
                        ),
                        TableColumnSpec(
                          label: 'Баллы',
                          sortField: 'points',
                          numeric: true,
                          build: (c) => Text('${c.card.points}'),
                        ),
                      ],
                    ],
                    actions:
                        (c) => [
                          EntityActions(
                            deleted: c.isDeleted,
                            onView: () => _openCustomer(context, c),
                            onEdit: () => context.go('/customers/${c.id}/edit'),
                            onDelete: () => notifier.softDelete(c.id),
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
