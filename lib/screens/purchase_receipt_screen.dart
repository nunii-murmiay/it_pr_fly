import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/pb_ids.dart';
import '../repositories/api_customer_repository.dart';
import '../state/auth_notifier.dart';

/// Чек покупки для покупателя.
class PurchaseReceiptScreen extends StatefulWidget {
  final String saleId;

  const PurchaseReceiptScreen({super.key, required this.saleId});

  @override
  State<PurchaseReceiptScreen> createState() => _PurchaseReceiptScreenState();
}

class _PurchaseReceiptScreenState extends State<PurchaseReceiptScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _sale;

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
      final cid = user?.customerId;
      if (cid == null || cid.isEmpty) {
        setState(() {
          _error = 'Учётка не связана с клиентом.';
          _loading = false;
        });
        return;
      }
      final sale = await context.read<ApiSalesRepository>().getSale(
        widget.saleId,
      );
      final saleCustomer = pbId(sale['customerId'] ?? sale['customer']);
      if (saleCustomer != cid) {
        setState(() {
          _error = 'Этот чек принадлежит другому покупателю.';
          _loading = false;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _sale = sale;
        _loading = false;
      });
    } on NotFoundException {
      if (!mounted) return;
      setState(() {
        _error = 'Чек не найден.';
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

  String _productName(Map<String, dynamic> line) {
    final product = line['product'];
    if (product is Map) {
      return product['name']?.toString() ?? 'Товар';
    }
    return 'Товар';
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final pad = narrow ? 12.0 : 16.0;
    final sale = _sale;
    final lines =
        (sale?['items'] as List?)?.whereType<Map>().toList() ?? const [];
    final customer = sale?['customer'] as Map?;
    final total = sale?['total'];
    final earned = sale?['pointsEarned'];
    final redeemed = sale?['pointsRedeemed'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Чек №${widget.saleId}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/my-purchases');
            }
          },
        ),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => context.go('/my-purchases'),
                        child: const Text('К списку покупок'),
                      ),
                    ],
                  ),
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
                            'Чек покупки',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text('Номер: ${sale?['id'] ?? widget.saleId}'),
                          Text(
                            'Покупатель: ${customer?['fullName'] ?? context.read<AuthNotifier>().user?.fullName ?? '—'}',
                          ),
                          if (customer?['phone'] != null)
                            Text('Телефон: ${customer!['phone']}'),
                          const Divider(height: 24),
                          Text(
                            'Позиции',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (lines.isEmpty)
                            const Text('В чеке нет позиций')
                          else
                            ...lines.map((raw) {
                              final line = Map<String, dynamic>.from(raw);
                              final qty = line['quantity'] ?? 0;
                              final unit = line['unitPrice'];
                              final unitNum =
                                  unit is num
                                      ? unit.toDouble()
                                      : double.tryParse('$unit') ?? 0;
                              final qtyNum =
                                  qty is num
                                      ? qty.toInt()
                                      : int.tryParse('$qty') ?? 0;
                              final lineTotal = unitNum * qtyNum;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _productName(line),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '$qtyNum × ${unitNum.toStringAsFixed(0)} ₽',
                                            style:
                                                Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text('${lineTotal.toStringAsFixed(0)} ₽'),
                                  ],
                                ),
                              );
                            }),
                          const Divider(height: 24),
                          Text(
                            'Итого: ${total ?? '—'} ₽',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (earned != null && earned != 0)
                            Text('Начислено баллов: +$earned'),
                          if (redeemed != null && redeemed != 0)
                            Text('Списано баллов: −$redeemed'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
