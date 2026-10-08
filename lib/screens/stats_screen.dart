import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api_exceptions.dart';
import '../core/supabase_map.dart';
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
  double stockValue = 0;

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
      final client = context.read<SupabaseClient>();
      Future<int> count(String table) async {
        final rows = await client.from(table).select('id').eq('deleted', false);
        return (rows as List).length;
      }

      final p = await count('products');
      final c = await count('customers');
      final s = await count('sales');
      final sup = await count('suppliers');
      final u = ((await client.from('profiles').select('id')) as List).length;
      final valuation = await client
          .from('inventory_valuation')
          .select('stock_value');
      var sum = 0.0;
      for (final row in (valuation as List).whereType<Map>()) {
        sum += (row['stock_value'] as num?)?.toDouble() ?? 0;
      }

      if (!mounted) return;
      setState(() {
        products = p;
        customers = c;
        sales = s;
        suppliers = sup;
        users = u;
        stockValue = sum;
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mapSupabaseError(e).message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthNotifier>().user;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final pad = narrow ? 12.0 : 16.0;

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
              : ListView(
                padding: EdgeInsets.all(pad),
                children: [
                  Text(
                    'Администратор: ${user?.fullName ?? '—'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _StatCard(title: 'Товары', value: '$products'),
                  _StatCard(title: 'Клиенты', value: '$customers'),
                  _StatCard(title: 'Продажи', value: '$sales'),
                  _StatCard(title: 'Поставщики', value: '$suppliers'),
                  _StatCard(title: 'Пользователи', value: '$users'),
                  _StatCard(
                    title: 'Остатки ₽',
                    value: stockValue.toStringAsFixed(0),
                  ),
                ],
              ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        trailing: Text(value, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
