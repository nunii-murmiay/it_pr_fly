import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/api_exceptions.dart';
import '../core/catalog_cache.dart';
import '../models/brand.dart';
import '../models/supplier.dart';
import '../repositories/brand_repository.dart';
import '../repositories/product_repository.dart';
import '../validation/validators.dart';
import '../widgets/chip_multi_select.dart';
import '../widgets/entity_form_shell.dart';

class BrandFormScreen extends StatefulWidget {
  final String? id;
  const BrandFormScreen({super.key, this.id});
  bool get isEditing => id != null;

  @override
  State<BrandFormScreen> createState() => _BrandFormScreenState();
}

class _BrandFormScreenState extends State<BrandFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  List<String> _supplierIds = [];
  List<Supplier> _suppliers = [];
  bool _loading = true;
  bool _dirty = false;
  bool _saving = false;
  Map<String, String> _serverErrors = {};
  Brand? _existing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cache = context.read<CatalogCache>();
    final brandRepo = context.read<BrandRepository>();
    _suppliers = await cache.suppliers();
    if (widget.id != null) {
      final found = await brandRepo.findById(widget.id!);
      if (found != null) {
        _existing = found;
        _nameCtrl.text = found.name;
        _countryCtrl.text = found.country;
        _descCtrl.text = found.description;
        _supplierIds = [...found.supplierIds];
      }
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
    final repo = context.read<BrandRepository>();
    final item = Brand(
      id: _existing?.id ?? '',
      name: _nameCtrl.text.trim(),
      country: _countryCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      supplierIds: _supplierIds,
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
      ).showSnackBar(const SnackBar(content: Text('Бренд сохранён')));
      context.go('/brands');
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
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return EntityFormShell(
      title: widget.isEditing ? 'Редактирование бренда' : 'Новый бренд',
      subtitle: 'Карточка бренда',
      icon: Icons.sell_outlined,
      formKey: _formKey,
      isDirty: _dirty,
      isEditing: widget.isEditing,
      isSaving: _saving,
      onCancel: () => context.go('/brands'),
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
                  max: 60,
                  field: 'Название',
                ),
              ),
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
        TextFormField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Описание *',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _markDirty(),
          validator:
              (v) => _fieldError(
                'description',
                AppValidators.minLength(v, 5, field: 'Описание'),
              ),
        ),
        const SizedBox(height: 16),
        ChipMultiSelectFormField(
          label: 'Поставщики бренда *',
          value: _supplierIds,
          options: _suppliers.map((s) => (id: s.id, name: s.name)).toList(),
          onChanged:
              (next) => setState(() {
                _supplierIds = next;
                _dirty = true;
              }),
          validator:
              (v) => _fieldError(
                'supplierIds',
                AppValidators.nonEmptyIds(v, field: 'поставщика'),
              ),
        ),
        if (widget.isEditing) ...[
          const SizedBox(height: 12),
          FutureBuilder<int>(
            future: context.read<ProductRepository>().countByBrand(widget.id!),
            builder:
                (context, snap) => Text('Связанных товаров: ${snap.data ?? 0}'),
          ),
        ],
      ],
    );
  }
}
