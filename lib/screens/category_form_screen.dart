import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/api_exceptions.dart';
import '../core/catalog_cache.dart';
import '../models/category.dart';
import '../repositories/category_repository.dart';
import '../repositories/product_repository.dart';
import '../validation/validators.dart';
import '../widgets/entity_form_shell.dart';

class CategoryFormScreen extends StatefulWidget {
  final String? id;
  const CategoryFormScreen({super.key, this.id});
  bool get isEditing => id != null;

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _iconName = 'category';
  bool _loading = true;
  bool _dirty = false;
  bool _saving = false;
  Map<String, String> _serverErrors = {};
  ProductCategory? _existing;

  static const _icons = [
    'pets',
    'sports_esports',
    'set_meal',
    'medical_services',
    'home',
    'category',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.id != null) {
      final found = await context.read<CategoryRepository>().findById(
        widget.id!,
      );
      if (found != null) {
        _existing = found;
        _nameCtrl.text = found.name;
        _descCtrl.text = found.description;
        _iconName = found.iconName;
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
    final repo = context.read<CategoryRepository>();
    final item = ProductCategory(
      id: _existing?.id ?? '',
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      iconName: _iconName,
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
      ).showSnackBar(const SnackBar(content: Text('Категория сохранена')));
      context.go('/categories');
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
    _descCtrl.dispose();
    super.dispose();
  }

  List<FormFieldSpec> get _fieldSpecs => [
    FormFieldSpec(
      builder:
          (_) => TextFormField(
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
    ),
    FormFieldSpec(
      builder:
          (_) => TextFormField(
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
    ),
    FormFieldSpec(
      builder:
          (_) => DropdownButtonFormField<String>(
            value: _iconName,
            decoration: const InputDecoration(
              labelText: 'Иконка',
              border: OutlineInputBorder(),
            ),
            items:
                _icons
                    .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                    .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _iconName = v;
                _dirty = true;
              });
            },
          ),
    ),
    if (widget.isEditing)
      FormFieldSpec(
        builder:
            (context) => FutureBuilder<int>(
              future: context.read<ProductRepository>().countByCategory(
                widget.id!,
              ),
              builder:
                  (context, snap) =>
                      Text('Связанных товаров: ${snap.data ?? 0}'),
            ),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return EntityFormShell(
      title: widget.isEditing ? 'Редактирование категории' : 'Новая категория',
      subtitle: 'Карточка категории',
      icon: Icons.category,
      formKey: _formKey,
      isDirty: _dirty,
      isEditing: widget.isEditing,
      isSaving: _saving,
      onCancel: () => context.go('/categories'),
      onSave: _save,
      fields: _fieldSpecs,
    );
  }
}
