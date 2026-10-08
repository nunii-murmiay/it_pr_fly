import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../models/customer.dart';
import '../repositories/api_customer_repository.dart';
import '../repositories/customer_repository.dart';
import '../state/auth_notifier.dart';

class MyPurchasesScreen extends StatefulWidget {
  const MyPurchasesScreen({super.key});

  @override
  State<MyPurchasesScreen> createState() => _MyPurchasesScreenState();
}

class _MyPurchasesScreenState extends State<MyPurchasesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  Customer? _customer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = context.read<AuthNotifier>().user;
      final customerRepo = context.read<CustomerRepository>();
      final salesRepo = context.read<ApiSalesRepository>();
      Customer? customer;
      if (user?.customerId != null) {
        customer = await customerRepo.findById(user!.customerId!);
      }

      var items = await salesRepo.listSales();
      final cid = user?.customerId;
      items =
          cid == null
              ? []
              : items.where((s) {
                final top = s['customerId']?.toString();
                final nested = (s['customer'] as Map?)?['id']?.toString();
                return top == cid || nested == cid;
              }).toList();
      if (!mounted) return;
      setState(() {
        _customer = customer;
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  String _saleTitle(Map<String, dynamic> s) {
    final lines = (s['items'] as List?) ?? const [];
    if (lines.isEmpty) return 'Чек №${s['id']}';
    if (lines.length == 1) {
      final product = lines.first is Map ? lines.first['product'] : null;
      final name =
          product is Map ? product['name']?.toString() : null;
      return name ?? 'Чек №${s['id']}';
    }
    return 'Чек · ${lines.length} поз.';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthNotifier>().user;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final pad = narrow ? 12.0 : 16.0;
    final card = _customer?.card;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои покупки'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                padding: EdgeInsets.all(pad),
                children: [
                  Text(
                    'Покупатель: ${user?.fullName ?? '—'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Нажмите на покупку, чтобы открыть полный чек.',
                  ),
                  if (card != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(narrow ? 12 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Карта лояльности',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text('Номер: ${card.number}'),
                            Text('Уровень: ${card.level}'),
                            Text('Баллы: ${card.points}'),
                            Text(
                              'Выдана: ${card.issuedAt.toLocal().toString().split('.').first}',
                            ),
                            if (_customer != null) ...[
                              const SizedBox(height: 4),
                              Text('Email: ${_customer!.email}'),
                              if (_customer!.phone.isNotEmpty)
                                Text('Телефон: ${_customer!.phone}'),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'История покупок',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Покупок пока нет')),
                    )
                  else
                    ..._items.map((s) {
                      final id = s['id']?.toString() ?? '';
                      final lines = (s['items'] as List?) ?? const [];
                      final earned = s['pointsEarned'];
                      final redeemed = s['pointsRedeemed'];
                      final loyalty = <String>[];
                      if (earned != null && earned != 0) {
                        loyalty.add('+$earned б.');
                      }
                      if (redeemed != null && redeemed != 0) {
                        loyalty.add('−$redeemed б.');
                      }
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: narrow,
                          leading: const Icon(Icons.receipt_long),
                          title: Text(
                            _saleTitle(s),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'Позиций: ${lines.length} · '
                            '${s['total'] ?? '—'} ₽'
                            '${loyalty.isEmpty ? '' : ' · ${loyalty.join(' ')}'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap:
                              id.isEmpty
                                  ? null
                                  : () => context.go('/my-purchases/$id'),
                        ),
                      );
                    }),
                ],
              ),
    );
  }
}
