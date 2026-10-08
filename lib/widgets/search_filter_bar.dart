import 'dart:async';
import 'package:flutter/material.dart';

import '../core/permissions.dart';
import 'access_scope.dart';
import '../models/brand.dart';
import '../models/brand_query.dart';
import '../models/category.dart';
import '../models/category_query.dart';
import '../models/customer_query.dart';
import '../models/loyalty_card.dart';
import '../models/product_query.dart';
import '../models/supplier.dart';
import '../models/supplier_query.dart';

class DebouncedSearchBar extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;
  final String hintText;

  const DebouncedSearchBar({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.hintText = 'Поиск...',
  });

  @override
  State<DebouncedSearchBar> createState() => _DebouncedSearchBarState();
}

class _DebouncedSearchBarState extends State<DebouncedSearchBar> {
  late TextEditingController _controller;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant DebouncedSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: (value) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 350), () {
          widget.onChanged(value);
        });
      },
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class ProductFilterPanel extends StatelessWidget {
  final ProductQuery query;
  final List<Supplier> suppliers;
  final List<ProductCategory> categories;
  final List<Brand> brands;
  final ValueChanged<ProductQuery> onQueryChanged;
  final VoidCallback onReset;

  const ProductFilterPanel({
    super.key,
    required this.query,
    required this.suppliers,
    required this.categories,
    required this.brands,
    required this.onQueryChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String?>(
                value: query.categoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Категория',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Все')),
                  ...categories.map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) => onQueryChanged(query.copyWith(categoryId: v)),
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String?>(
                value: query.brandId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Бренд',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Все')),
                  ...brands.map(
                    (b) => DropdownMenuItem(
                      value: b.id,
                      child: Text(b.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) => onQueryChanged(query.copyWith(brandId: v)),
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String?>(
                value: query.supplierId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Поставщик',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Все')),
                  ...suppliers.map(
                    (s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) => onQueryChanged(query.copyWith(supplierId: v)),
              ),
            ),
            RoleGate(
              operation: AppOperation.restoreDeleted,
              child: FilterChip(
                label: const Text('Удалённые'),
                selected: query.includeDeleted,
                onSelected:
                    (v) => onQueryChanged(query.copyWith(includeDeleted: v)),
              ),
            ),
            TextButton(onPressed: onReset, child: const Text('Сбросить')),
          ],
        ),
      ),
    );
  }
}

class SupplierFilterPanel extends StatelessWidget {
  final SupplierQuery query;
  final ValueChanged<SupplierQuery> onQueryChanged;
  final VoidCallback onReset;

  const SupplierFilterPanel({
    super.key,
    required this.query,
    required this.onQueryChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    const countries = [
      'Франция',
      'США',
      'Германия',
      'Италия',
      'Нидерланды',
      'Россия',
      'Бельгия',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                value: query.country,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Страна',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Все страны'),
                  ),
                  ...countries.map(
                    (c) => DropdownMenuItem(value: c, child: Text(c)),
                  ),
                ],
                onChanged: (v) => onQueryChanged(query.copyWith(country: v)),
              ),
            ),
            RoleGate(
              operation: AppOperation.restoreDeleted,
              child: FilterChip(
                label: const Text('Удалённые'),
                selected: query.includeDeleted,
                onSelected:
                    (v) => onQueryChanged(query.copyWith(includeDeleted: v)),
              ),
            ),
            TextButton(onPressed: onReset, child: const Text('Сбросить')),
          ],
        ),
      ),
    );
  }
}

class BrandFilterPanel extends StatelessWidget {
  final BrandQuery query;
  final ValueChanged<BrandQuery> onQueryChanged;
  final VoidCallback onReset;

  const BrandFilterPanel({
    super.key,
    required this.query,
    required this.onQueryChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          children: [
            RoleGate(
              operation: AppOperation.restoreDeleted,
              child: FilterChip(
                label: const Text('Удалённые'),
                selected: query.includeDeleted,
                onSelected:
                    (v) => onQueryChanged(query.copyWith(includeDeleted: v)),
              ),
            ),
            TextButton(onPressed: onReset, child: const Text('Сбросить')),
          ],
        ),
      ),
    );
  }
}

class CategoryFilterPanel extends StatelessWidget {
  final CategoryQuery query;
  final ValueChanged<CategoryQuery> onQueryChanged;
  final VoidCallback onReset;

  const CategoryFilterPanel({
    super.key,
    required this.query,
    required this.onQueryChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          children: [
            RoleGate(
              operation: AppOperation.restoreDeleted,
              child: FilterChip(
                label: const Text('Удалённые'),
                selected: query.includeDeleted,
                onSelected:
                    (v) => onQueryChanged(query.copyWith(includeDeleted: v)),
              ),
            ),
            TextButton(onPressed: onReset, child: const Text('Сбросить')),
          ],
        ),
      ),
    );
  }
}

class CustomerFilterPanel extends StatelessWidget {
  final CustomerQuery query;
  final ValueChanged<CustomerQuery> onQueryChanged;
  final VoidCallback onReset;

  const CustomerFilterPanel({
    super.key,
    required this.query,
    required this.onQueryChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          children: [
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String?>(
                value: query.cardLevel,
                decoration: const InputDecoration(
                  labelText: 'Уровень карты',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Все')),
                  ...LoyaltyCard.levels.map(
                    (l) => DropdownMenuItem(value: l, child: Text(l)),
                  ),
                ],
                onChanged: (v) => onQueryChanged(query.copyWith(cardLevel: v)),
              ),
            ),
            RoleGate(
              operation: AppOperation.restoreDeleted,
              child: FilterChip(
                label: const Text('Удалённые'),
                selected: query.includeDeleted,
                onSelected:
                    (v) => onQueryChanged(query.copyWith(includeDeleted: v)),
              ),
            ),
            TextButton(onPressed: onReset, child: const Text('Сбросить')),
          ],
        ),
      ),
    );
  }
}
