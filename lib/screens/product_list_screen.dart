import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/breakpoints.dart';
import '../core/catalog_cache.dart';
import '../core/permissions.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import '../models/role.dart';
import '../models/supplier.dart';
import '../state/auth_notifier.dart';
import '../state/product_list_notifier.dart';
import '../widgets/access_scope.dart';
import '../widgets/adaptive_entity.dart';
import '../widgets/entity_table.dart';
import '../widgets/list_load_body.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/product_card.dart';
import '../widgets/record_dialog.dart';
import '../widgets/responsive_chrome.dart';
import '../widgets/search_filter_bar.dart';

class ProductListScreen extends StatefulWidget {
  final ProductQuery initialQuery;
  const ProductListScreen({super.key, required this.initialQuery});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  bool _showFilters = false;
  List<Supplier> _suppliers = [];
  List<ProductCategory> _categories = [];
  List<Brand> _brands = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<ProductListNotifier>().applyQuery(widget.initialQuery);
      final cache = context.read<CatalogCache>();
      final suppliers = await cache.suppliers();
      final categories = await cache.categories();
      final brands = await cache.brands();
      if (mounted) {
        setState(() {
          _suppliers = suppliers;
          _categories = categories;
          _brands = brands;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProductListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ProductListNotifier>().applyQuery(widget.initialQuery);
      });
    }
  }

  void _updateUrl(ProductQuery q) {
    final params = <String, String>{};
    if (q.search.isNotEmpty) params['search'] = q.search;
    if (q.categoryId != null) params['categoryId'] = '${q.categoryId}';
    if (q.brandId != null) params['brandId'] = '${q.brandId}';
    if (q.supplierId != null) params['supplierId'] = '${q.supplierId}';
    if (q.priceFrom != null) params['priceFrom'] = '${q.priceFrom}';
    if (q.priceTo != null) params['priceTo'] = '${q.priceTo}';
    if (q.sortField != 'name') params['sort'] = q.sortField;
    if (!q.sortAscending) params['asc'] = 'false';
    if (q.page > 1) params['page'] = '${q.page}';
    if (q.size != 10) params['size'] = '${q.size}';
    if (q.includeDeleted) params['includeDeleted'] = 'true';
    context.go(
      Uri(
        path: '/products',
        queryParameters: params.isEmpty ? null : params,
      ).toString(),
    );
  }

  String _supplierName(String id) =>
      _suppliers.where((s) => s.id == id).map((s) => s.name).firstOrNull ?? '—';

  String _categoriesLabel(Product p) {
    if (p.categoryNames.isNotEmpty) return p.categoryNames.join(', ');
    return p.categoryIds
        .map(
          (id) =>
              _categories
                  .where((c) => c.id == id)
                  .map((c) => c.name)
                  .firstOrNull ??
              '#$id',
        )
        .join(', ');
  }

  Future<void> _openProduct(Product product) {
    return showProductViewDialog(
      context,
      product: product,
      supplierName: _supplierName(product.supplierId),
      categoriesLabel: _categoriesLabel(product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ProductListNotifier>();
    final isBuyer = context.watch<AuthNotifier>().user?.role == Role.reader;
    final theme = Theme.of(context);
    final phone = MediaQuery.sizeOf(context).width < Breakpoints.phone;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.pets, color: Color(0xFF0F766E), semanticLabel: 'ЗооМаг'),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Каталог товаров',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
            onPressed: () => notifier.load(),
          ),
        ],
      ),
      floatingActionButton: RoleGate(
        operation: AppOperation.manageCatalog,
        child: ResponsiveAddButton(
          onPressed: () => context.go('/products/new'),
          label: 'Добавить товар',
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(phone ? 8 : 16),
        child: Column(
          children: [
            ListToolbar(
              search: DebouncedSearchBar(
                initialValue: notifier.query.search,
                hintText:
                    isBuyer
                        ? 'Поиск по названию...'
                        : 'Поиск по названию или артикулу...',
                onChanged:
                    (text) => _updateUrl(notifier.query.copyWith(search: text)),
              ),
              filtersOpen: _showFilters,
              onToggleFilters:
                  () => setState(() => _showFilters = !_showFilters),
              filtersPanel: ProductFilterPanel(
                query: notifier.query,
                suppliers: _suppliers,
                categories: _categories,
                brands: _brands,
                onQueryChanged: _updateUrl,
                onReset: () => _updateUrl(const ProductQuery()),
              ),
            ),
            if (notifier.hasSelection) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Выбрано: ${notifier.selected.length}'),
                    if (notifier.query.includeDeleted)
                      RoleGate(
                        operation: AppOperation.restoreDeleted,
                        child: TextButton(
                          onPressed: () => notifier.restoreSelected(),
                          child: const Text('Восстановить'),
                        ),
                      ),
                    RoleGate(
                      operation: AppOperation.manageCatalog,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                        ),
                        onPressed: () => notifier.deleteSelected(),
                        child: const Text('Удалить'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(child: _content(notifier, isBuyer: isBuyer)),
          ],
        ),
      ),
    );
  }

  Widget _content(ProductListNotifier notifier, {required bool isBuyer}) {
    return ListLoadBody(
      status: notifier.status,
      error: notifier.error,
      isEmpty: notifier.result.items.isEmpty,
      emptyMessage: 'Товары не найдены',
      onRetry: () => notifier.load(),
      child: Builder(
        builder: (context) {
          final items = notifier.result.items;
          return Column(
            children: [
              Expanded(
                child: AdaptiveEntityBody(
                  cards: [
                    for (final item in items)
                      ProductCard(
                        product: item,
                        supplierName: _supplierName(item.supplierId),
                        isSelected: notifier.selected.contains(item.id),
                        showSku: !isBuyer,
                        onView: () => _openProduct(item),
                        onToggleSelect: notifier.toggleSelection,
                        onEdit: () => context.go('/products/${item.id}/edit'),
                        onDelete: () => notifier.softDelete(item.id),
                        onRestore: () => notifier.restore(item.id),
                        onHardDelete: () => notifier.hardDelete(item.id),
                      ),
                  ],
                  table: EntityTable<Product>(
                    items: items,
                    idOf: (p) => p.id,
                    selected: notifier.selected,
                    onToggleSelect: notifier.toggleSelection,
                    onToggleSelectAll:
                        () => notifier.toggleSelectAll(
                          items.map((p) => p.id).toList(),
                        ),
                    sortField: notifier.query.sortField,
                    sortAscending: notifier.query.sortAscending,
                    isDeletedOf: (p) => p.isDeleted,
                    onSort:
                        (field) => _updateUrl(
                          notifier.query.copyWith(
                            sortField: field,
                            sortAscending:
                                field == notifier.query.sortField
                                    ? !notifier.query.sortAscending
                                    : true,
                          ),
                        ),
                    columns: [
                      if (!isBuyer)
                        TableColumnSpec(
                          label: 'Артикул',
                          sortField: 'sku',
                          build: (p) => clipText(p.sku),
                        ),
                      TableColumnSpec(
                        label: 'Название',
                        sortField: 'name',
                        build:
                            (p) => ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 280),
                              child: clipText(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                      ),
                      TableColumnSpec(
                        label: 'Категории',
                        build:
                            (p) => ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: clipText(_categoriesLabel(p)),
                            ),
                      ),
                      TableColumnSpec(
                        label: 'Поставщик',
                        build:
                            (p) => ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: clipText(
                                p.supplierName ?? _supplierName(p.supplierId),
                              ),
                            ),
                      ),
                      TableColumnSpec(
                        label: 'Цена',
                        sortField: 'price',
                        numeric: true,
                        build: (p) => Text('${p.price.toStringAsFixed(0)} ₽'),
                      ),
                      TableColumnSpec(
                        label: 'Склад',
                        sortField: 'stock',
                        numeric: true,
                        build: (p) => Text('${p.stock}'),
                      ),
                    ],
                    actions:
                        (p) => [
                          EntityActions(
                            deleted: p.isDeleted,
                            onView: () => _openProduct(p),
                            onEdit: () => context.go('/products/${p.id}/edit'),
                            onDelete: () => notifier.softDelete(p.id),
                            onRestore: () => notifier.restore(p.id),
                            onHardDelete: () => notifier.hardDelete(p.id),
                          ),
                        ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
                    (s) =>
                        _updateUrl(notifier.query.copyWith(size: s, page: 1)),
              ),
            ],
          );
        },
      ),
    );
  }
}
