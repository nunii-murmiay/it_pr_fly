import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../repositories/api_customer_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/product_repository.dart';

class _CartLine {
  String? productId;
  final TextEditingController qty;

  _CartLine({this.productId, String qtyText = '1'})
    : qty = TextEditingController(text: qtyText);

  void dispose() => qty.dispose();
}

String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _sales = [];
  List<Customer> _customers = [];
  List<Product> _products = [];
  String? _customerId;
  final List<_CartLine> _lines = [];
  final Map<String, String> _lineErrors = {};
  bool _saving = false;
  Timer? _customersTimer;

  final _customerSearchCtrl = TextEditingController();
  String _customerSearch = '';
  bool _redeemPoints = false;
  final _redeemCtrl = TextEditingController(text: '0');
  String? _redeemError;

  @override
  void initState() {
    super.initState();
    _lines.add(_CartLine());
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _customersTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshCustomers(),
    );
  }

  @override
  void dispose() {
    _customersTimer?.cancel();
    _customerSearchCtrl.dispose();
    _redeemCtrl.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Customer? get _selectedCustomer {
    if (_customerId == null) return null;
    for (final c in _customers) {
      if (c.id == _customerId) return c;
    }
    return null;
  }

  List<Customer> get _filteredCustomers {
    final q = _customerSearch.trim().toLowerCase();
    final qDigits = _digitsOnly(_customerSearch);
    if (q.isEmpty) return _customers;
    return _customers.where((c) {
      final name = c.fullName.toLowerCase();
      final phone = c.phone.toLowerCase();
      final phoneDigits = _digitsOnly(c.phone);
      if (name.contains(q) || phone.contains(q)) return true;
      if (qDigits.isNotEmpty && phoneDigits.contains(qDigits)) return true;
      return false;
    }).toList();
  }

  double get _cartSubtotal {
    var sum = 0.0;
    for (final line in _lines) {
      if (line.productId == null) continue;
      final qty = int.tryParse(line.qty.text.trim()) ?? 0;
      if (qty < 1) continue;
      final product = _products.where((p) => p.id == line.productId).firstOrNull;
      if (product == null) continue;
      sum += product.price * qty;
    }
    return sum;
  }

  int get _redeemRequested {
    if (!_redeemPoints) return 0;
    return int.tryParse(_redeemCtrl.text.trim()) ?? 0;
  }

  int get _maxRedeemable {
    final customer = _selectedCustomer;
    if (customer == null) return 0;
    final byPoints = customer.card.points;
    final byTotal = _cartSubtotal.floor();
    return byPoints < byTotal ? byPoints : byTotal;
  }

  Future<void> _refreshCustomers() async {
    if (!mounted || _loading || _saving) return;
    try {
      final customers = await context.read<CustomerRepository>().findAll();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _ensureCustomerSelection();
      });
    } catch (_) {}
  }

  void _ensureCustomerSelection() {
    final filtered = _filteredCustomers;
    if (_customerId != null && filtered.any((c) => c.id == _customerId)) {
      return;
    }
    _customerId = filtered.isNotEmpty ? filtered.first.id : null;
    if (_customerId == null &&
        _customers.isNotEmpty &&
        _customerSearch.trim().isEmpty) {
      _customerId = _customers.first.id;
    }
  }

  void _addLine() {
    setState(() {
      final id = _products.isNotEmpty ? _products.first.id : null;
      _lines.add(_CartLine(productId: id));
    });
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final customerRepo = context.read<CustomerRepository>();
      final productRepo = context.read<ProductRepository>();
      final salesRepo = context.read<ApiSalesRepository>();
      final customers = await customerRepo.findAll();
      final products = await productRepo.findAll();
      final sales = await salesRepo.listSales();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _products = products;
        _sales = sales;
        _ensureCustomerSelection();
        for (final line in _lines) {
          if (line.productId == null ||
              products.every((p) => p.id != line.productId)) {
            line.productId = products.isNotEmpty ? products.first.id : null;
          }
        }
        _loading = false;
      });
    } on ForbiddenException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('403: ${e.message}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _createSale() async {
    if (_customerId == null) return;

    final toSubmit = <({String productId, int quantity})>[];
    for (final line in _lines) {
      if (line.productId == null) continue;
      final qty = int.tryParse(line.qty.text.trim()) ?? 0;
      if (qty < 1) continue;
      toSubmit.add((productId: line.productId!, quantity: qty));
    }

    if (toSubmit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы один товар с количеством ≥ 1'),
        ),
      );
      return;
    }

    final shortages = <String, String>{};
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (line.productId == null) continue;
      final qty = int.tryParse(line.qty.text.trim()) ?? 0;
      if (qty < 1) continue;
      final product = _products.where((p) => p.id == line.productId).firstOrNull;
      if (product != null && qty > product.stock) {
        shortages['$i'] =
            'Недостаточно «${product.name}»: на складе ${product.stock}';
      }
    }
    if (shortages.isNotEmpty) {
      setState(() {
        _lineErrors
          ..clear()
          ..addAll(shortages);
      });
      return;
    }

    final redeem = _redeemRequested;
    if (_redeemPoints && redeem > 0) {
      final max = _maxRedeemable;
      if (redeem > max) {
        setState(() {
          _redeemError =
              max <= 0
                  ? 'Нет баллов для списания'
                  : 'Можно списать не больше $max';
        });
        return;
      }
    }

    setState(() {
      _saving = true;
      _lineErrors.clear();
      _redeemError = null;
    });
    try {
      final repo = context.read<ApiSalesRepository>();
      final result = await repo.createSale(
        customerId: _customerId!,
        items: toSubmit,
        pointsToRedeem: _redeemPoints ? redeem : 0,
      );
      if (!mounted) return;
      final earned = result['pointsEarned'];
      final spent = result['pointsRedeemed'];
      final parts = <String>['Продажа оформлена'];
      if (spent is num && spent > 0) parts.add('списано ${spent.toInt()} баллов');
      if (earned is num && earned > 0) {
        parts.add('начислено ${earned.toInt()}');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parts.join(' · '))));
      for (final line in _lines) {
        line.qty.text = '1';
      }
      _redeemPoints = false;
      _redeemCtrl.text = '0';
      await _load();
    } on ConflictException catch (e) {
      if (!mounted) return;
      final index = _lines.indexWhere((line) => line.productId == e.productId);
      final product = _products.where((p) => p.id == e.productId).firstOrNull;
      final text =
          product == null
              ? e.message
              : 'Недостаточно «${product.name}»: на складе ${product.stock}';
      if (index >= 0) {
        setState(() => _lineErrors['$index'] = text);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } on ValidationException catch (e) {
      if (!mounted) return;
      final field = e.errors['pointsToRedeem'];
      setState(() => _redeemError = field ?? e.message);
    } on ForbiddenException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('403: ${e.message}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final pad = narrow ? 12.0 : 16.0;
    final filtered = _filteredCustomers;
    final customer = _selectedCustomer;
    final subtotal = _cartSubtotal;
    final redeem = _redeemPoints ? _redeemRequested.clamp(0, _maxRedeemable) : 0;
    final payable = (subtotal - redeem).clamp(0, double.infinity);
    final willEarn = (payable / 100).floor();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Касса'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: EdgeInsets.all(pad),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              )
              : ListView(
                padding: EdgeInsets.all(pad),
                children: [
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(narrow ? 12 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Оформить продажу',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _customerSearchCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Поиск клиента',
                              hintText: 'Телефон или ФИО',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.phone,
                            onChanged: (v) {
                              setState(() {
                                _customerSearch = v;
                                _ensureCustomerSelection();
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value:
                                filtered.any((c) => c.id == _customerId)
                                    ? _customerId
                                    : null,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Клиент',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              helperText:
                                  filtered.isEmpty
                                      ? 'Никого не найдено по запросу'
                                      : 'Найдено: ${filtered.length}',
                            ),
                            items:
                                filtered
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(
                                          '${c.fullName} · ${c.phone} · ${c.card.points} б.',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                filtered.isEmpty
                                    ? null
                                    : (v) => setState(() {
                                      _customerId = v;
                                      _redeemError = null;
                                    }),
                          ),
                          if (customer != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'На карте: ${customer.card.points} баллов '
                              '(${customer.card.level})',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text(
                            'Товары в чеке',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(_lines.length, (i) {
                            final line = _lines[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          // ignore: deprecated_member_use
                                          value: line.productId,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            labelText: 'Товар ${i + 1}',
                                            border: const OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          items:
                                              _products
                                                  .map(
                                                    (p) => DropdownMenuItem(
                                                      value: p.id,
                                                      child: Text(
                                                        '${p.name} (склад: ${p.stock})',
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                          onChanged:
                                              (v) => setState(() {
                                                line.productId = v;
                                                _lineErrors.remove('$i');
                                              }),
                                        ),
                                      ),
                                      if (_lines.length > 1) ...[
                                        const SizedBox(width: 4),
                                        IconButton(
                                          tooltip: 'Убрать строку',
                                          onPressed: () => _removeLine(i),
                                          icon: const Icon(Icons.close),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: line.qty,
                                    decoration: InputDecoration(
                                      labelText: 'Количество',
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      errorText: _lineErrors['$i'],
                                      errorMaxLines: 3,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged:
                                        (_) => setState(
                                          () => _lineErrors.remove('$i'),
                                        ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          OutlinedButton.icon(
                            onPressed: _products.isEmpty ? null : _addLine,
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить товар'),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Списать баллы клиента'),
                            subtitle: Text(
                              customer == null
                                  ? 'Выберите клиента'
                                  : '1 балл = 1 ₽ · макс. $_maxRedeemable',
                            ),
                            value: _redeemPoints,
                            onChanged:
                                customer == null || customer.card.points < 1
                                    ? null
                                    : (v) => setState(() {
                                      _redeemPoints = v;
                                      _redeemError = null;
                                      if (!v) _redeemCtrl.text = '0';
                                    }),
                          ),
                          if (_redeemPoints) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: _redeemCtrl,
                              decoration: InputDecoration(
                                labelText: 'Сколько баллов списать',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                errorText: _redeemError,
                                suffixText: 'из $_maxRedeemable',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged:
                                  (_) => setState(() => _redeemError = null),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            'Сумма: ${subtotal.toStringAsFixed(0)} ₽'
                            '${redeem > 0 ? ' − $redeem б. = ${payable.toStringAsFixed(0)} ₽' : ''}'
                            '${willEarn > 0 ? ' · +$willEarn б. за покупку' : ''}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed:
                                _saving || _customerId == null
                                    ? null
                                    : _createSale,
                            icon: const Icon(Icons.point_of_sale),
                            label: const Text('Оформить чек'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Все продажи',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ..._sales.map((s) {
                    final product = s['product'] as Map<String, dynamic>?;
                    final saleCustomer = s['customer'] as Map<String, dynamic>?;
                    final redeemed = s['pointsRedeemed'];
                    final earned = s['pointsEarned'];
                    final loyaltyBits = <String>[];
                    if (earned != null && earned != 0) {
                      loyaltyBits.add('+$earned б.');
                    }
                    if (redeemed != null && redeemed != 0) {
                      loyaltyBits.add('−$redeemed б.');
                    }
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: narrow,
                        title: Text(
                          product?['name']?.toString() ?? 'Товар',
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${saleCustomer?['fullName'] ?? 'Клиент'} · '
                          '×${s['quantity'] ?? '—'} · ${s['total'] ?? s['totalPrice'] ?? '—'} ₽'
                          '${loyaltyBits.isEmpty ? '' : ' · ${loyaltyBits.join(' ')}'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }),
                ],
              ),
    );
  }
}
