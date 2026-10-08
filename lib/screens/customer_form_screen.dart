import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/api_exceptions.dart';
import '../core/breakpoints.dart';
import '../models/customer.dart';
import '../models/loyalty_card.dart';
import '../repositories/customer_repository.dart';
import '../validation/validators.dart';
import '../widgets/entity_form_shell.dart';

class CustomerFormScreen extends StatefulWidget {
  final String? id;
  const CustomerFormScreen({super.key, this.id});
  bool get isEditing => id != null;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController();
  String _level = 'Стандарт';
  DateTime _issuedAt = DateTime.now();
  bool _loading = true;
  bool _dirty = false;
  bool _saving = false;
  Map<String, String> _serverErrors = {};
  Customer? _existing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.id != null) {
      final found = await context.read<CustomerRepository>().findById(
        widget.id!,
      );
      if (found != null) {
        _existing = found;
        _nameCtrl.text = found.fullName;
        _emailCtrl.text = found.email;
        _phoneCtrl.text = found.phone;
        _cardNumberCtrl.text = found.card.number;
        _pointsCtrl.text = found.card.points.toString();
        _level = found.card.level;
        _issuedAt = found.card.issuedAt;
      }
    } else {
      _cardNumberCtrl.text =
          'LC-${DateTime.now().millisecondsSinceEpoch % 100000}';
      _pointsCtrl.text = '0';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  String? _fieldError(String key, String? local) => _serverErrors[key] ?? local;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _serverErrors = {});
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final repo = context.read<CustomerRepository>();
    final item = Customer(
      id: _existing?.id ?? '',
      fullName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      card: LoyaltyCard(
        number: _cardNumberCtrl.text.trim(),
        issuedAt: _issuedAt,
        points: int.parse(_pointsCtrl.text.trim()),
        level: _level,
      ),
      deletedAt: _existing?.deletedAt,
    );

    try {
      if (_existing == null) {
        await repo.create(item);
      } else {
        await repo.update(item);
      }
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Клиент сохранён')));
      context.go('/customers');
    } on ValidationException catch (e) {
      setState(() => _serverErrors = e.errors);
      _formKey.currentState!.validate();
    } on ConflictException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cardNumberCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return EntityFormShell(
      title: widget.isEditing ? 'Редактирование клиента' : 'Новый клиент',
      subtitle: 'Клиент и карта лояльности',
      icon: Icons.person_outline,
      formKey: _formKey,
      isDirty: _dirty,
      isEditing: widget.isEditing,
      isSaving: _saving,
      onCancel: () => context.go('/customers'),
      onSave: _save,
      children: [
        TextFormField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'ФИО *',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _markDirty(),
          validator:
              (v) => _fieldError(
                'fullName',
                AppValidators.lengthRange(v, min: 3, max: 100, field: 'ФИО'),
              ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailCtrl,
          decoration: const InputDecoration(
            labelText: 'Email *',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) {
            _markDirty();
            if (_serverErrors.containsKey('email')) {
              setState(() => _serverErrors.remove('email'));
            }
          },
          validator: (v) => _fieldError('email', AppValidators.email(v)),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneCtrl,
          decoration: const InputDecoration(
            labelText: 'Телефон *',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _markDirty(),
          validator: (v) => _fieldError('phone', AppValidators.phone(v)),
        ),
        const SizedBox(height: 24),
        Text(
          'Карта лояльности',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Связь один к одному: карта редактируется прямо в форме клиента',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _cardNumberCtrl,
          decoration: const InputDecoration(
            labelText: 'Номер карты *',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _markDirty(),
          validator:
              (v) => _fieldError(
                'cardNumber',
                AppValidators.minLength(v, 4, field: 'Номер карты'),
              ),
        ),
        const SizedBox(height: 16),
        FieldWrap(
          children: [
            TextFormField(
              controller: _pointsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Баллы *',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _markDirty(),
              validator:
                  (v) => _fieldError(
                    'points',
                    AppValidators.nonNegativeInt(v, field: 'Баллы'),
                  ),
            ),
            DropdownButtonFormField<String>(
              value: _level,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Уровень *',
                border: OutlineInputBorder(),
              ),
              items:
                  LoyaltyCard.levels
                      .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _level = v;
                  _dirty = true;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Дата выдачи карты'),
          subtitle: Text(
            '${_issuedAt.day.toString().padLeft(2, '0')}.'
            '${_issuedAt.month.toString().padLeft(2, '0')}.'
            '${_issuedAt.year}',
          ),
          trailing: OutlinedButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _issuedAt,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _issuedAt = picked;
                  _dirty = true;
                });
              }
            },
            child: const Text('Выбрать'),
          ),
        ),
      ],
    );
  }
}
