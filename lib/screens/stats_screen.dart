import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/api_exceptions.dart';
import '../state/auth_notifier.dart';

/// Статистика магазина — экран только для администратора.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _loading = true;
  String? _error;
  int products = 0;
  int customers = 0;
  int sales = 0;
  int suppliers = 0;
  int users = 0;

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
      final dio = context.read<Dio>();
      Future<int> total(String path) async {
        final data = await guard(() async {
          final r = await dio.get(path);
          return r.data as Map<String, dynamic>;
        });
        return (data['totalItems'] as num?)?.toInt() ?? 0;
      }

      final p = await total('/collections/products/records?perPage=1');
      final c = await total('/collections/customers/records?perPage=1');
      final s = await total('/collections/sales/records?perPage=1');
      final sup = await total('/collections/suppliers/records?perPage=1');
      final u = await total('/collections/users/records?perPage=1');

      if (!mounted) return;
      setState(() {
        products = p;
        customers = c;
        sales = s;
        suppliers = sup;
        users = u;
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

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthNotifier>().user?.role.label ?? '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Сводка магазина (роль: $role)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _StatCard('Товары', products, Icons.inventory_2),
                        _StatCard('Клиенты', customers, Icons.people),
                        _StatCard('Продажи', sales, Icons.point_of_sale),
                        _StatCard('Поставщики', suppliers, Icons.business),
                        _StatCard(
                          'Пользователи',
                          users,
                          Icons.admin_panel_settings,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _StatCard(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                '$value',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
