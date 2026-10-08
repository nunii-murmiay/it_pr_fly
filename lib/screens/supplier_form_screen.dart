import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/api_exceptions.dart';
import '../core/breakpoints.dart';
import '../core/catalog_cache.dart';
import '../models/supplier.dart';
import '../repositories/product_repository.dart';
import '../repositories/supplier_repository.dart';
import '../validation/validators.dart';
import '../widgets/entity_form_shell.dart';

class SupplierFormScreen extends StatefulWidget {
  final String? id;
  const SupplierFormScreen({super.key, this.id});
  bool get isEditing => id != null;

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _ratingCtrl = TextEditingController();
  bool _loading = true;
  bool _dirty = false;
  bool _saving = false;
  Map<String, String> _serverErrors = {};
  Supplier? _existing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.id != null) {
      final found = await context.read<SupplierRepository>().findById(
        widget.id!,
      );
      if (found != null) {
        _existing = found;
        _nameCtrl.text = found.name;
        _countryCtrl.text = found.country;
        _contactCtrl.text = found.contactPerson;
        _phoneCtrl.text = found.phone;
        _emailCtrl.text = found.email;
        _ratingCtrl.text = found.rating.toString();
      }
    } else {
      _countryCtrl.text = 'Россия';
      _ratingCtrl.text = '4.5';
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
    final repo = context.read<SupplierRepository>();
    final item = Supplier(
      id: _existing?.id ?? '',
      name: _nameCtrl.text.trim(),
      country: _countryCtrl.text.trim(),
      contactPerson: _contactCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      rating: double.parse(_ratingCtrl.text.trim().replaceAll(',', '.')),
      deletedAt: _existing?.deletedAt,
    );

    try {
      if (_existing == null) {
        await repo.create(item);
      } else {
        await repo.update(item);
      }
      if (!mounted) return;
      context.read<CatalogCache>().invalidate();
      setState(() => _dirty = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Поставщик сохранён')));
      context.go('/suppliers');
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
    _countryCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _ratingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return EntityFormShell(
      title: widget.isEditing ? 'Редактирование поставщика' : 'Новый поставщик',
      subtitle: 'Карточка поставщика',
      icon: Icons.business,
      formKey: _formKey,
      isDirty: _dirty,
      isEditing: widget.isEditing,
      isSaving: _saving,
      onCancel: () => context.go('/suppliers'),
      onSave: _save,
      children: [
        TextFormField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Название *',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _markDirty(),
          validator:
              (v) => _fieldError(
                'name',
                AppValidators.lengthRange(
                  v,
                  min: 2,
                  max: 80,
                  field: 'Название',
                ),
              ),
        ),
        const SizedBox(height: 16),
        FieldWrap(
          children: [
            TextFormField(
              controller: _countryCtrl,
              decoration: const InputDecoration(
                labelText: 'Страна *',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _markDirty(),
              validator:
                  (v) => _fieldError(
                    'country',
                    AppValidators.required(v, field: 'Страна'),
                  ),
            ),
            TextFormField(
              controller: _ratingCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Рейтинг *',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _markDirty(),
              validator:
                  (v) => _fieldError(
                    'rating',
                    AppValidators.rangeDouble(
                      v,
                      min: 1,
                      max: 5,
                      field: 'Рейтинг',
                    ),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _contactCtrl,
          decoration: const InputDecoration(
            labelText: 'Контактное лицо *',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _markDirty(),
          validator:
              (v) => _fieldError(
                'contactPerson',
                AppValidators.minLength(v, 2, field: 'Контактное лицо'),
              ),
        ),
        const SizedBox(height: 16),
        FieldWrap(
          fieldWidth: 240,
          children: [
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Телефон *',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _markDirty(),
              validator: (v) => _fieldError('phone', AppValidators.phone(v)),
            ),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email *',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _markDirty(),
              validator: (v) => _fieldError('email', AppValidators.email(v)),
            ),
          ],
        ),
        if (widget.isEditing) ...[
          const SizedBox(height: 12),
          FutureBuilder<int>(
            future: context.read<ProductRepository>().countBySupplier(
              widget.id!,
            ),
            builder: (context, snap) {
              final n = snap.data ?? 0;
              return Text(
                'Связанных товаров: $n',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              );
            },
          ),
        ],
      ],
    );
  }
}
