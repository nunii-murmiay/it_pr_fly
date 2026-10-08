import 'package:flutter/material.dart';

import '../core/breakpoints.dart';

/// Описание поля формы — список таких описаний передаётся в [EntityFormShell].
class FormFieldSpec {
  final Widget Function(BuildContext context) builder;

  const FormFieldSpec({required this.builder});
}

/// Общая форма для всех сущностей (п.18 задания).
///
/// Общее: разметка Card + заголовок, Form, кнопки, PopScope, обработка отправки.
/// Поля задаются списком [fields] (или [children] как сокращение).
class EntityFormShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final GlobalKey<FormState> formKey;
  final bool isDirty;
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onCancel;
  final Future<void> Function() onSave;
  final List<Widget> children;
  final List<FormFieldSpec>? fields;

  const EntityFormShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.formKey,
    required this.isDirty,
    required this.isEditing,
    required this.onCancel,
    required this.onSave,
    this.isSaving = false,
    this.children = const [],
    this.fields,
  });

  Future<bool> _confirmLeave(BuildContext context) async {
    if (!isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Несохранённые изменения'),
            content: ConstrainedBox(
              constraints: Breakpoints.dialogConstraints,
              child: Text(
                'Вы изменили данные, но не сохранили их. Уйти без сохранения?',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Остаться'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Уйти'),
              ),
            ],
          ),
    );
    return result == true;
  }

  List<Widget> _buildFields(BuildContext context) {
    if (fields != null && fields!.isNotEmpty) {
      final out = <Widget>[];
      for (var i = 0; i < fields!.length; i++) {
        if (i > 0) out.add(const SizedBox(height: 16));
        out.add(fields![i].builder(context));
      }
      return out;
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave(context);
        if (leave && context.mounted) {
          onCancel();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            tooltip: 'Назад',
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final leave = await _confirmLeave(context);
              if (leave) onCancel();
            },
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final phone = constraints.maxWidth < Breakpoints.phone;
            return SingleChildScrollView(
              padding: EdgeInsets.all(phone ? 12 : 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(phone ? 16 : 28),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  icon,
                                  size: 28,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    subtitle,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            ..._buildFields(context),
                            const SizedBox(height: 28),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () async {
                                    final leave = await _confirmLeave(context);
                                    if (leave) onCancel();
                                  },
                                  child: const Text('Отмена'),
                                ),
                                FilledButton.icon(
                                  onPressed: isSaving ? null : onSave,
                                  icon:
                                      isSaving
                                          ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : const Icon(Icons.save),
                                  label: Text(
                                    isSaving
                                        ? 'Сохранение...'
                                        : (isEditing ? 'Сохранить' : 'Создать'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
